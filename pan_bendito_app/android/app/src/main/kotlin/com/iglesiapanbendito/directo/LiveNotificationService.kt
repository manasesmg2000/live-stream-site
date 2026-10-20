package com.iglesiapanbendito.directo

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class LiveNotificationService : Service() {
    private var isRunning = false
    private var sseThread: Thread? = null
    private var lastKnownLiveState: Boolean? = null

    companion object {
        const val CHANNEL_ID = "pan_bendito_live"
        const val TOPIC_URL = "https://ntfy.sh/iglesia-pan-bendito-live-channel-v1"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            isRunning = true
            startListening()
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Cultos en Directo",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificaciones de inicio y fin de culto en directo de Pan Bendito"
                enableVibration(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startListening() {
        sseThread?.interrupt()
        sseThread = Thread {
            while (isRunning) {
                try {
                    val url = URL("$TOPIC_URL/sse")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.connectTimeout = 15000
                    conn.readTimeout = 0 // Sin timeout para SSE permanente
                    conn.setRequestProperty("Accept", "text/event-stream")

                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    reader.forEachLine { line ->
                        if (!isRunning) return@forEachLine
                        val currentLine = line.trim()
                        if (currentLine.startsWith("data:")) {
                            val jsonStr = currentLine.substring(5).trim()
                            handleMessage(jsonStr)
                        }
                    }
                } catch (e: Exception) {
                    try {
                        Thread.sleep(8000)
                    } catch (_: InterruptedException) {
                        break
                    }
                }
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    private fun handleMessage(jsonStr: String) {
        try {
            val json = JSONObject(jsonStr)
            val event = json.optString("event")
            val msg = json.optString("message").trim()

            if (event == "message" && msg.isNotEmpty()) {
                if (msg.startsWith("LIVE:")) {
                    if (lastKnownLiveState != true) {
                        lastKnownLiveState = true
                        showNotification(
                            1001,
                            "🔴 ¡Estamos EN DIRECTO!",
                            "Ha comenzado el culto en directo de Pan Bendito. Toca para verlo."
                        )
                    }
                } else if (msg.startsWith("OFFLINE")) {
                    if (lastKnownLiveState != false) {
                        lastKnownLiveState = false
                        showNotification(
                            1002,
                            "⏹ Culto finalizado",
                            "El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior."
                        )
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun showNotification(id: Int, title: String, text: String) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(id, builder.build())
        } catch (_: Exception) {}
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val restartIntent = Intent(applicationContext, LiveNotificationService::class.java)
            val pendingIntent = PendingIntent.getService(
                this, 1, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.set(AlarmManager.RTC, System.currentTimeMillis() + 1500, pendingIntent)
        } catch (_: Exception) {}
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        sseThread?.interrupt()
        sseThread = null
        super.onDestroy()
    }
}
