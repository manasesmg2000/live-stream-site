package com.iglesiapanbendito.directo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object NotificationHelper {
    const val LIVE_CHANNEL_ID = "pan_bendito_live"
    const val CALENDAR_CHANNEL_ID = "pan_bendito_calendar"
    const val PREFS_NAME = "pan_bendito_stream_state"
    const val KEY_LAST_CALENDAR_MSG_ID = "last_processed_calendar_ntfy_id"

    @Synchronized
    fun handleCalendarMessage(context: Context, currentId: String, jsonPayload: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val lastCalId = prefs.getString(KEY_LAST_CALENDAR_MSG_ID, "") ?: ""
            if (currentId.isNotEmpty() && currentId == lastCalId) {
                return
            }

            val obj = JSONObject(jsonPayload)
            val title = obj.optString("title", "📅 Calendario de Cultos").trim()
            val body = obj.optString("body", "Nuevo evento en el calendario de Pan Bendito.").trim()
            val imageUrl = obj.optString("imageUrl", "").trim()

            if (currentId.isNotEmpty()) {
                prefs.edit().putString(KEY_LAST_CALENDAR_MSG_ID, currentId).apply()
            }

            val bigPicture = if (imageUrl.isNotEmpty()) downloadBitmap(imageUrl) else null
            val notifId = if (currentId.isNotEmpty()) (2000 + (currentId.hashCode() and 0x0FFF)) else 2001

            showCalendarNotification(context, notifId, title, body, bigPicture)
        } catch (_: Exception) {}
    }

    private fun downloadBitmap(urlStr: String): Bitmap? {
        return try {
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 6000
            conn.readTimeout = 6000
            conn.instanceFollowRedirects = true
            conn.setRequestProperty("User-Agent", "PanBenditoApp/1.0")
            if (conn.responseCode == 200) {
                conn.inputStream.use { stream ->
                    val opts = BitmapFactory.Options().apply {
                        inPreferredConfig = Bitmap.Config.ARGB_8888
                    }
                    BitmapFactory.decodeStream(stream, null, opts)
                }
            } else null
        } catch (_: Exception) {
            null
        }
    }

    private fun showCalendarNotification(
        context: Context,
        id: Int,
        title: String,
        message: String,
        bigPicture: Bitmap?
    ) {
        try {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val audioAttrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

                val channel = NotificationChannel(
                    CALENDAR_CHANNEL_ID,
                    "Calendario y Cultos Especiales",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Avisos de cultos, reuniones y cultos especiales de Pan Bendito"
                    enableVibration(true)
                    enableLights(true)
                    setSound(soundUri, audioAttrs)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_tab", "calendario")
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pendingIntent = PendingIntent.getActivity(context, id, launchIntent, flags)

            val smallIcon = android.R.drawable.stat_notify_chat

            val builder = NotificationCompat.Builder(context, CALENDAR_CHANNEL_ID)
                .setSmallIcon(smallIcon)
                .setContentTitle(title)
                .setContentText(message)
                .setSound(soundUri)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)

            if (bigPicture != null) {
                builder.setLargeIcon(bigPicture)
                builder.setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(bigPicture)
                        .bigLargeIcon(null as Bitmap?)
                        .setSummaryText(message)
                )
            } else {
                builder.setStyle(NotificationCompat.BigTextStyle().bigText(message))
                try {
                    val logoId = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
                    if (logoId != 0) {
                        val logo = BitmapFactory.decodeResource(context.resources, logoId)
                        if (logo != null) builder.setLargeIcon(logo)
                    }
                } catch (_: Exception) {}
            }

            notificationManager.notify(id, builder.build())
        } catch (_: Exception) {}
    }
}
