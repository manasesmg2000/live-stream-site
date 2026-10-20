package com.iglesiapanbendito.directo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileWriter

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.iglesiapanbendito.directo/native"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 1. Activar MulticastLock para evitar que Android bloquee el tráfico de red local
        try {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            if (wifi != null) {
                multicastLock = wifi.createMulticastLock("pan_bendito_multicast_lock")
                multicastLock?.setReferenceCounted(true)
                multicastLock?.acquire()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Crear canal de notificaciones nativo
        createNotificationChannel()

        // 3. Solicitar permiso de notificaciones en Android 13+ (API 33+) al abrir la app
        requestNotificationPermission()

        // 4. Iniciar servicio en segundo plano para recibir notificaciones aunque la app esté cerrada
        try {
            val serviceIntent = Intent(this, LiveNotificationService::class.java)
            startService(serviceIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getUserName" -> {
                    val prefs = getSharedPreferences("pan_bendito_prefs", Context.MODE_PRIVATE)
                    result.success(prefs.getString("user_name", null))
                }
                "saveUserName" -> {
                    val name = call.argument<String>("name") ?: ""
                    val prefs = getSharedPreferences("pan_bendito_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("user_name", name).apply()
                    result.success(true)
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "logAccess" -> {
                    val name = call.argument<String>("name") ?: ""
                    val date = call.argument<String>("date") ?: ""
                    try {
                        val file = File(filesDir, "registro_accesos.txt")
                        val writer = FileWriter(file, true)
                        writer.append("$date - $name\n")
                        writer.flush()
                        writer.close()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "showLiveNotification" -> {
                    val title = call.argument<String>("title") ?: "🔴 ¡Estamos EN DIRECTO!"
                    val body = call.argument<String>("body") ?: "Ha comenzado el culto en directo de Pan Bendito. Toca para ver."
                    showNotification(title, body)
                    result.success(true)
                }
                "openYouTube" -> {
                    val videoId = call.argument<String>("videoId") ?: ""
                    val success = launchYouTube(videoId)
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Cultos en Directo"
            val descriptionText = "Notificaciones de emisiones en vivo de la Iglesia Pan Bendito"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel("pan_bendito_live", name, importance).apply {
                description = descriptionText
                enableVibration(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(title: String, message: String) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val builder = NotificationCompat.Builder(this, "pan_bendito_live")
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(777, builder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun launchYouTube(videoId: String): Boolean {
        return try {
            val appIntent = Intent(Intent.ACTION_VIEW, Uri.parse("vnd.youtube:$videoId"))
            appIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(appIntent)
            true
        } catch (e: Exception) {
            try {
                val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/watch?v=$videoId"))
                webIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(webIntent)
                true
            } catch (e2: Exception) {
                false
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            multicastLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
