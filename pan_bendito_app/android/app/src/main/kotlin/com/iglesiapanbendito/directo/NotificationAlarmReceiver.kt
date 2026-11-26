package com.iglesiapanbendito.directo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

open class NotificationAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val LIVE_CHANNEL_ID = "pan_bendito_live"
        const val PREFS_NAME = "pan_bendito_stream_state"
        const val KEY_LAST_LIVE = "last_live_state"
        const val KEY_LAST_NOTIFIED_VID = "last_notified_vid"
        const val KEY_LAST_MSG_ID = "last_processed_ntfy_id"

        val NTFY_POLL_URLS = listOf(
            "https://ntfy.sh/iglesia-pan-bendito-live-channel-v1/json?poll=1&since=10m",
            "https://ntfy.envs.net/iglesia-pan-bendito-live-channel-v1/json?poll=1&since=10m",
            "https://ntfy.projectsegfau.lt/iglesia-pan-bendito-live-channel-v1/json?poll=1&since=10m"
        )
        const val RAW_CONFIG_URL = "https://raw.githubusercontent.com/manasesmg2000/live-stream-site/main/config.json"
        const val PAGES_CONFIG_URL = "https://manasesmg2000.github.io/live-stream-site/config.json"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "panbendito:alarm_receiver_wakelock")
        try {
            wakeLock?.acquire(15000L)
        } catch (_: Exception) {}

        Thread {
            try {
                checkStreamAndNotify(context)
            } catch (_: Exception) {
            } finally {
                NotificationScheduler.scheduleNext(context)
                try {
                    if (wakeLock?.isHeld == true) {
                        wakeLock.release()
                    }
                } catch (_: Exception) {}
                pendingResult.finish()
            }
        }.start()
    }

    private fun checkStreamAndNotify(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastProcessedId = prefs.getString(KEY_LAST_MSG_ID, "") ?: ""
        var newestMsgId = ""
        var isLive: Boolean? = null
        var videoId: String = ""
        var eventType: String = "" // "LIVE" o "OFFLINE"

        // 1. Consultar ntfy para eventos inmediatos recientes
        for (pollUrl in NTFY_POLL_URLS) {
            try {
                val ntfyResp = fetchUrl(pollUrl)
                if (!ntfyResp.isNullOrEmpty()) {
                    val lines = ntfyResp.trim().split("\n").filter { it.isNotBlank() }
                    for (line in lines.reversed()) {
                        try {
                            val item = JSONObject(line)
                            if (item.optString("event") == "message") {
                                val currentId = item.optString("id", "").trim()
                                val msg = item.optString("message", "").trim()

                                if (currentId.isNotEmpty() && msg.startsWith("CALENDAR|")) {
                                    NotificationHelper.handleCalendarMessage(context, currentId, msg.substring(9))
                                } else if (currentId.isNotEmpty() && currentId != lastProcessedId) {
                                    if (msg.startsWith("LIVE:")) {
                                        val payload = msg.substring(5)
                                        val parts = payload.split("|")
                                        videoId = parts.getOrNull(0)?.trim() ?: ""
                                        isLive = true
                                        eventType = "LIVE"
                                        newestMsgId = currentId
                                        break
                                    } else if (msg.startsWith("OFFLINE")) {
                                        isLive = false
                                        eventType = "OFFLINE"
                                        newestMsgId = currentId
                                        break
                                    }
                                }
                            }
                        } catch (_: Exception) {}
                    }
                    if (isLive != null) break
                }
            } catch (_: Exception) {}
        }

        // 2. Si no hubo mensaje nuevo en ntfy, comprobar config.json en GitHub
        if (isLive == null) {
            try {
                val configResp = fetchUrl("$RAW_CONFIG_URL?_t=${System.currentTimeMillis()}")
                    ?: fetchUrl("$PAGES_CONFIG_URL?_t=${System.currentTimeMillis()}")
                if (!configResp.isNullOrEmpty()) {
                    val json = JSONObject(configResp)
                    val liveInConfig = json.optBoolean("live", false)
                    val vidInConfig = json.optString("videoId", "").trim()
                    val wasLive = prefs.getBoolean(KEY_LAST_LIVE, false)
                    val lastVid = prefs.getString(KEY_LAST_NOTIFIED_VID, "") ?: ""

                    if (liveInConfig && vidInConfig.isNotEmpty()) {
                        if (!wasLive || lastVid != vidInConfig) {
                            isLive = true
                            videoId = vidInConfig
                            eventType = "LIVE"
                        }
                    } else if (!liveInConfig && wasLive) {
                        isLive = false
                        eventType = "OFFLINE"
                    }
                }
            } catch (_: Exception) {}
        }

        // 3. Emitir notificación si hay un evento
        if (eventType == "LIVE" && isLive == true) {
            val editor = prefs.edit()
                .putBoolean(KEY_LAST_LIVE, true)
            if (videoId.isNotEmpty()) {
                editor.putString(KEY_LAST_NOTIFIED_VID, videoId)
            }
            if (newestMsgId.isNotEmpty()) {
                editor.putString(KEY_LAST_MSG_ID, newestMsgId)
            }
            editor.apply()

            showNotification(
                context,
                1001,
                "🔴 ¡Estamos EN DIRECTO!",
                "Ha comenzado el culto en directo de Pan Bendito. Toca para verlo."
            )
        } else if (eventType == "OFFLINE" && isLive == false) {
            val editor = prefs.edit()
                .putBoolean(KEY_LAST_LIVE, false)
            if (newestMsgId.isNotEmpty()) {
                editor.putString(KEY_LAST_MSG_ID, newestMsgId)
            }
            editor.apply()

            showNotification(
                context,
                1002,
                "⏹ Culto finalizado",
                "El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior."
            )
        }
    }

    private fun fetchUrl(urlStr: String): String? {
        return try {
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 6000
            conn.readTimeout = 6000
            conn.useCaches = false
            conn.setRequestProperty("Cache-Control", "no-cache")
            conn.setRequestProperty("User-Agent", "PanBenditoApp/1.0")
            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8"))
                val content = reader.readText()
                reader.close()
                content
            } else null
        } catch (_: Exception) {
            null
        }
    }

    private fun showNotification(context: Context, id: Int, title: String, message: String) {
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
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pendingIntent = PendingIntent.getActivity(context, id, launchIntent, flags)

            // Icono pequeño seguro del sistema para evitar incompatibilidades de XML adaptativo
            val smallIcon = android.R.drawable.stat_notify_chat

            val builder = NotificationCompat.Builder(context, LIVE_CHANNEL_ID)
                .setSmallIcon(smallIcon)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setSound(soundUri)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)

            // Añadir icono grande con el logo de la iglesia si está disponible
            try {
                val logoId = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
                if (logoId != 0) {
                    val bitmap = BitmapFactory.decodeResource(context.resources, logoId)
                    if (bitmap != null) {
                        builder.setLargeIcon(bitmap)
                    }
                }
            } catch (_: Exception) {}

            notificationManager.notify(id, builder.build())
        } catch (_: Exception) {}
    }
}
