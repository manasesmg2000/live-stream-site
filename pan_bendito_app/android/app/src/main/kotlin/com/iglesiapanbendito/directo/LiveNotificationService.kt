package com.iglesiapanbendito.directo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

open class LiveNotificationService : Service() {
    private var isRunning = false
    private var workerThread: Thread? = null

    companion object {
        const val LIVE_CHANNEL_ID = "pan_bendito_live"
        const val PREFS_NAME = "pan_bendito_stream_state"
        const val KEY_LAST_LIVE = "last_live_state"
        const val KEY_LAST_NOTIFIED_VID = "last_notified_vid"
        const val KEY_LAST_MSG_ID = "last_processed_ntfy_id"

        val NTFY_SSE_SERVERS = listOf(
            "https://ntfy.sh/iglesia-pan-bendito-live-channel-v1/sse",
            "https://ntfy.envs.net/iglesia-pan-bendito-live-channel-v1/sse",
            "https://ntfy.projectsegfau.lt/iglesia-pan-bendito-live-channel-v1/sse"
        )
        const val GITHUB_CONFIG_URL = "https://raw.githubusercontent.com/manasesmg2000/live-stream-site/main/config.json"
        const val GITHUB_PAGES_URL = "https://manasesmg2000.github.io/live-stream-site/config.json"

        fun start(context: Context) {
            try {
                val intent = Intent(context, LiveNotificationService::class.java)
                context.startService(intent)
            } catch (_: Exception) {}
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            isRunning = true
            startBackgroundWorker()
        }
        return START_NOT_STICKY
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val liveChannel = NotificationChannel(
                LIVE_CHANNEL_ID,
                "Cultos en Directo",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Avisos de inicio y fin de culto en vivo de Pan Bendito"
                enableVibration(true)
                enableLights(true)
                setSound(soundUri, audioAttrs)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(liveChannel)
        }
    }

    private fun startBackgroundWorker() {
        workerThread?.interrupt()
        workerThread = Thread {
            var currentServerIndex = 0

            while (isRunning) {
                val serverUrl = NTFY_SSE_SERVERS[currentServerIndex % NTFY_SSE_SERVERS.size]
                var sseConnected = false

                try {
                    val url = URL(serverUrl)
                    val conn = url.openConnection() as HttpURLConnection
                    conn.connectTimeout = 12000
                    conn.readTimeout = 45000
                    conn.setRequestProperty("Accept", "text/event-stream")
                    conn.setRequestProperty("User-Agent", "PanBenditoApp/1.0")

                    if (conn.responseCode == 200) {
                        sseConnected = true
                        val reader = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8"))
                        reader.forEachLine { line ->
                            if (!isRunning) return@forEachLine
                            val trimmed = line.trim()
                            if (trimmed.startsWith("data:")) {
                                val jsonStr = trimmed.substring(5).trim()
                                handleEventJson(jsonStr)
                            }
                        }
                        reader.close()
                    }
                } catch (_: Exception) {
                    currentServerIndex++
                }

                if (!sseConnected || !isRunning) {
                    try {
                        checkGitHubConfigFallback()
                    } catch (_: Exception) {}
                }

                try {
                    Thread.sleep(if (sseConnected) 5000 else 15000)
                } catch (_: InterruptedException) {
                    break
                }
            }
        }.apply {
            isDaemon = false
            name = "PanBendito-SSE-Worker"
            start()
        }
    }

    private fun handleEventJson(jsonStr: String) {
        try {
            val json = JSONObject(jsonStr)
            val event = json.optString("event")
            val msg = json.optString("message", "").trim()

            if (event == "message" && msg.isNotEmpty()) {
                val currentId = json.optString("id", "").trim()
                if (msg.startsWith("CALENDAR|")) {
                    NotificationHelper.handleCalendarMessage(this, currentId, msg.substring(9))
                    return
                }

                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val lastProcessedId = prefs.getString(KEY_LAST_MSG_ID, "") ?: ""

                if (currentId.isNotEmpty() && currentId == lastProcessedId) {
                    return // Ya procesado
                }

                if (msg.startsWith("LIVE:")) {
                    val payload = msg.substring(5)
                    val videoId = payload.split("|").getOrNull(0)?.trim() ?: ""
                    prefs.edit()
                        .putBoolean(KEY_LAST_LIVE, true)
                        .putString(KEY_LAST_NOTIFIED_VID, videoId)
                        .putString(KEY_LAST_MSG_ID, currentId)
                        .apply()
                    showLiveNotification(
                        1001,
                        "🔴 ¡Estamos EN DIRECTO!",
                        "Ha comenzado el culto en directo de Pan Bendito. Toca para verlo."
                    )
                } else if (msg.startsWith("OFFLINE")) {
                    prefs.edit()
                        .putBoolean(KEY_LAST_LIVE, false)
                        .putString(KEY_LAST_MSG_ID, currentId)
                        .apply()
                    showLiveNotification(
                        1002,
                        "⏹ Culto finalizado",
                        "El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior."
                    )
                }
            }
        } catch (_: Exception) {}
    }

    private fun checkGitHubConfigFallback() {
        try {
            val urlStr = "$GITHUB_CONFIG_URL?_t=${System.currentTimeMillis()}"
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 6000
            conn.readTimeout = 6000
            conn.useCaches = false
            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8"))
                val content = reader.readText()
                reader.close()
                val json = JSONObject(content)
                val live = json.optBoolean("live", false)
                val videoId = json.optString("videoId", "").trim()

                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val wasLive = prefs.getBoolean(KEY_LAST_LIVE, false)
                val lastVid = prefs.getString(KEY_LAST_NOTIFIED_VID, "") ?: ""

                if (live && videoId.isNotEmpty()) {
                    if (!wasLive || lastVid != videoId) {
                        prefs.edit()
                            .putBoolean(KEY_LAST_LIVE, true)
                            .putString(KEY_LAST_NOTIFIED_VID, videoId)
                            .apply()
                        showLiveNotification(
                            1001,
                            "🔴 ¡Estamos EN DIRECTO!",
                            "Ha comenzado el culto en directo de Pan Bendito. Toca para verlo."
                        )
                    }
                } else if (!live && wasLive) {
                    prefs.edit()
                        .putBoolean(KEY_LAST_LIVE, false)
                        .apply()
                    showLiveNotification(
                        1002,
                        "⏹ Culto finalizado",
                        "El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior."
                    )
                }
            }
        } catch (_: Exception) {}
    }

    private fun showLiveNotification(id: Int, title: String, text: String) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pendingIntent = PendingIntent.getActivity(this, id, intent, flags)

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val smallIcon = android.R.drawable.stat_notify_chat

            val builder = NotificationCompat.Builder(this, LIVE_CHANNEL_ID)
                .setSmallIcon(smallIcon)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setSound(soundUri)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)

            try {
                val logoId = resources.getIdentifier("ic_launcher", "mipmap", packageName)
                if (logoId != 0) {
                    val bitmap = BitmapFactory.decodeResource(resources, logoId)
                    if (bitmap != null) {
                        builder.setLargeIcon(bitmap)
                    }
                }
            } catch (_: Exception) {}

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(id, builder.build())
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        isRunning = false
        workerThread?.interrupt()
        workerThread = null
        try {
            NotificationScheduler.scheduleNext(applicationContext)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
