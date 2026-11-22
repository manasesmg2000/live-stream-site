package com.iglesiapanbendito.directo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class LiveNotificationService : Service() {
    private var isRunning = false
    private var workerThread: Thread? = null
    private var lastKnownLiveState: Boolean? = null
    private var lastKnownVideoId: String = ""

    companion object {
        const val LIVE_CHANNEL_ID = "pan_bendito_live"
        const val SERVICE_CHANNEL_ID = "pan_bendito_service"
        const val SERVICE_NOTIFICATION_ID = 9001

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
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {}
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
        promoteToForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        promoteToForeground()
        if (!isRunning) {
            isRunning = true
            startBackgroundWorker()
        }
        return START_STICKY
    }

    private fun promoteToForeground() {
        try {
            val serviceNotification = buildServiceNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    SERVICE_NOTIFICATION_ID,
                    serviceNotification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(SERVICE_NOTIFICATION_ID, serviceNotification)
            }
        } catch (_: Exception) {}
    }

    private fun buildServiceNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getActivity(this, 9000, launchIntent, flags)

        val iconRes = if (applicationInfo.icon != 0) applicationInfo.icon else android.R.drawable.ic_dialog_info

        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setSmallIcon(iconRes)
            .setContentTitle("Iglesia Pan Bendito")
            .setContentText("Servicio de alertas de cultos activo")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 1. Canal silencioso para el servicio en primer plano
            val serviceChannel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Servicio de Segundo Plano",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantiene activa la recepción de notificaciones cuando la app está cerrada"
                setShowBadge(false)
            }
            manager.createNotificationChannel(serviceChannel)

            // 2. Canal prioritario para alertas de directos
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
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
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
                    conn.readTimeout = 45000 // Timeout si no hay pings de ntfy
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
                    // Si falla la conexión SSE, rotar al siguiente servidor
                    currentServerIndex++
                }

                // Fallback directo a GitHub si SSE se desconectó
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
            isDaemon = false // NO daemon para que sobreviva a la finalización de hilos secundarios
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
                if (msg.startsWith("LIVE:")) {
                    val payload = msg.substring(5)
                    val videoId = payload.split("|").getOrNull(0)?.trim() ?: ""
                    if (videoId.isNotEmpty() && (lastKnownLiveState != true || lastKnownVideoId != videoId)) {
                        lastKnownLiveState = true
                        lastKnownVideoId = videoId
                        showLiveNotification(
                            1001,
                            "🔴 ¡Estamos EN DIRECTO!",
                            "Ha comenzado el culto en directo de Pan Bendito. Toca para verlo."
                        )
                    }
                } else if (msg.startsWith("OFFLINE")) {
                    if (lastKnownLiveState == true) {
                        lastKnownLiveState = false
                        showLiveNotification(
                            1002,
                            "⏹ Culto finalizado",
                            "El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior."
                        )
                    }
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

                if (live && videoId.isNotEmpty()) {
                    if (lastKnownLiveState != true || lastKnownVideoId != videoId) {
                        lastKnownLiveState = true
                        lastKnownVideoId = videoId
                        showLiveNotification(
                            1001,
                            "🔴 ¡Estamos EN DIRECTO!",
                            "Ha comenzado el culto en directo de Pan Bendito. Toca para verlo."
                        )
                    }
                } else if (!live && lastKnownLiveState == true) {
                    lastKnownLiveState = false
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
            val iconRes = if (applicationInfo.icon != 0) applicationInfo.icon else android.R.drawable.ic_dialog_info

            val builder = NotificationCompat.Builder(this, LIVE_CHANNEL_ID)
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

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(id, builder.build())
        } catch (_: Exception) {}
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            NotificationScheduler.scheduleNext(applicationContext)
            // Relanzar servicio si el usuario desliza la app de la lista de recientes
            LiveNotificationService.start(applicationContext)
        } catch (_: Exception) {}
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        workerThread?.interrupt()
        workerThread = null
        try {
            NotificationScheduler.scheduleNext(applicationContext)
            LiveNotificationService.start(applicationContext)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
