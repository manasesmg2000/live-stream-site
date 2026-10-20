package com.iglesiapanbendito.directo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class NotificationAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL_ID = "pan_bendito_live"
        const val PREFS_NAME = "pan_bendito_stream_state"
        const val KEY_LAST_LIVE = "last_live_state"
        const val KEY_LAST_NOTIFIED_VID = "last_notified_vid"
        const val CONFIG_URL = "https://manasesmg2000.github.io/live-stream-site/config.json"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()

        Thread {
            try {
                checkStreamAndNotify(context)
            } catch (_: Exception) {
            } finally {
                // Programar la siguiente comprobación en segundo plano
                NotificationScheduler.scheduleNext(context)
                pendingResult.finish()
            }
        }.start()
    }

    private fun checkStreamAndNotify(context: Context) {
        val url = URL("$CONFIG_URL?_t=${System.currentTimeMillis()}")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 7000
        conn.readTimeout = 7000
        conn.useCaches = false
        conn.setRequestProperty("Cache-Control", "no-cache")

        if (conn.responseCode != 200) return

        val reader = BufferedReader(InputStreamReader(conn.inputStream))
        val sb = StringBuilder()
        reader.forEachLine { sb.append(it) }
        reader.close()

        val json = JSONObject(sb.toString())
        val isLive = json.optBoolean("live", false)
        val videoId = json.optString("videoId", "").trim()

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val wasLive = prefs.getBoolean(KEY_LAST_LIVE, false)
        val lastNotifiedVid = prefs.getString(KEY_LAST_NOTIFIED_VID, "") ?: ""

        if (isLive && videoId.isNotEmpty()) {
            // Si acaba de empezar el directo o es un vídeo nuevo y no se ha notificado
            if (!wasLive || videoId != lastNotifiedVid) {
                prefs.edit()
                    .putBoolean(KEY_LAST_LIVE, true)
                    .putString(KEY_LAST_NOTIFIED_VID, videoId)
                    .apply()

                showNotification(
                    context,
                    1001,
                    "🔴 ¡Estamos EN DIRECTO!",
                    "Ha comenzado el culto en directo de Pan Bendito. Toca para verlo."
                )
            }
        } else if (!isLive) {
            // Si estaba en directo y ahora ha terminado
            if (wasLive) {
                prefs.edit()
                    .putBoolean(KEY_LAST_LIVE, false)
                    .apply()

                showNotification(
                    context,
                    1002,
                    "⏹ Culto finalizado",
                    "El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior."
                )
            }
        }
    }

    private fun showNotification(context: Context, id: Int, title: String, message: String) {
        try {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Cultos en Directo",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Avisos de inicio y fin de culto en vivo de Pan Bendito"
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                id,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(context.applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setSound(soundUri)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)

            notificationManager.notify(id, builder.build())
        } catch (_: Exception) {}
    }
}
