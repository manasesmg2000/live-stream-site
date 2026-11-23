package com.iglesiapanbendito.directo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker que Android garantiza ejecutar periódicamente
 * incluso con la app completamente cerrada y el móvil en reposo.
 *
 * WorkManager es la única API que Android garantiza que se ejecuta
 * bajo cualquier condición (Doze, app killed, reinicio del dispositivo).
 */
class LiveNotificationWorker(
    private val context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        const val WORK_NAME = "pan_bendito_live_check"
        const val LIVE_CHANNEL_ID = "pan_bendito_live"
        const val PREFS_NAME = "pan_bendito_stream_state"
        const val KEY_LAST_LIVE = "last_live_state"
        const val KEY_LAST_NOTIFIED_VID = "last_notified_vid"

        val CONFIG_URLS = listOf(
            "https://manasesmg2000.github.io/live-stream-site/config.json",
            "https://raw.githubusercontent.com/manasesmg2000/live-stream-site/main/config.json"
        )

        fun schedulePeriodicWork(context: Context) {
            try {
                val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()

                // Mínimo permitido por WorkManager = 15 minutos
                // Usamos 15 min — Android lo ejecutará aunque esté en Doze
                val workRequest = PeriodicWorkRequestBuilder<LiveNotificationWorker>(
                    15, TimeUnit.MINUTES
                )
                    .setConstraints(constraints)
                    .build()

                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP, // Si ya existe, no lo reemplaza
                    workRequest
                )
            } catch (_: Exception) {}
        }
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            ensureNotificationChannel()
            checkAndNotify()
            Result.success()
        } catch (_: Exception) {
            Result.retry()
        }
    }

    private fun checkAndNotify() {
        var isLive: Boolean? = null
        var videoId = ""

        // Consultar config.json (fuente de verdad)
        for (url in CONFIG_URLS) {
            try {
                val content = fetchUrl("$url?_t=${System.currentTimeMillis()}")
                if (!content.isNullOrEmpty()) {
                    val json = JSONObject(content)
                    isLive = json.optBoolean("live", false)
                    videoId = json.optString("videoId", "").trim()
                    break
                }
            } catch (_: Exception) {}
        }

        if (isLive == null) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val wasLive = prefs.getBoolean(KEY_LAST_LIVE, false)
        val lastVid = prefs.getString(KEY_LAST_NOTIFIED_VID, "") ?: ""

        if (isLive == true && videoId.isNotEmpty()) {
            if (!wasLive || videoId != lastVid) {
                prefs.edit()
                    .putBoolean(KEY_LAST_LIVE, true)
                    .putString(KEY_LAST_NOTIFIED_VID, videoId)
                    .apply()
                showNotification(
                    1001,
                    "🔴 ¡Estamos EN DIRECTO!",
                    "Ha comenzado el culto en directo de Pan Bendito. Toca para verlo."
                )
            }
        } else if (isLive == false && wasLive) {
            prefs.edit()
                .putBoolean(KEY_LAST_LIVE, false)
                .apply()
            showNotification(
                1002,
                "⏹ Culto finalizado",
                "El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior."
            )
        }
    }

    private fun fetchUrl(urlStr: String): String? {
        return try {
            val conn = URL(urlStr).openConnection() as HttpURLConnection
            conn.connectTimeout = 8000
            conn.readTimeout = 8000
            conn.useCaches = false
            conn.setRequestProperty("Cache-Control", "no-cache")
            conn.setRequestProperty("User-Agent", "PanBenditoApp/1.0")
            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8"))
                val text = reader.readText()
                reader.close()
                text
            } else null
        } catch (_: Exception) { null }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(LIVE_CHANNEL_ID) == null) {
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                val channel = NotificationChannel(
                    LIVE_CHANNEL_ID,
                    "Cultos en Directo",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Avisos de inicio y fin de culto en vivo de Pan Bendito"
                    enableVibration(true)
                    enableLights(true)
                    setSound(soundUri, audioAttrs)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun showNotification(id: Int, title: String, text: String) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pendingIntent = PendingIntent.getActivity(context, id, intent, flags)

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val iconRes = if (context.applicationInfo.icon != 0) context.applicationInfo.icon
                          else android.R.drawable.ic_dialog_info

            val notification = NotificationCompat.Builder(context, LIVE_CHANNEL_ID)
                .setSmallIcon(iconRes)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setSound(soundUri)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(id, notification)
        } catch (_: Exception) {}
    }
}
