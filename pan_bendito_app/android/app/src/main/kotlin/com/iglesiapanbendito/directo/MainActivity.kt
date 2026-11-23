package com.iglesiapanbendito.directo

import android.app.AlertDialog
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

open class MainActivity: FlutterActivity() {
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

        // 4. Iniciar servicio en primer plano y programador de alarmas
        LiveNotificationService.start(this)
        NotificationScheduler.scheduleNext(this)

        // 5. Preguntar de forma amable si desea desactivar optimización de batería (sin llevar a ajustes a la fuerza)
        requestBatteryOptimizationExemption()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101 && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            LiveNotificationService.start(this)
            NotificationScheduler.scheduleNext(this)
        }
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val prefs = getSharedPreferences("pan_bendito_prefs", Context.MODE_PRIVATE)
                val asked = prefs.getBoolean("battery_dialog_prompted", false)
                val powerManager = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
                if (powerManager != null && !powerManager.isIgnoringBatteryOptimizations(packageName) && !asked) {
                    AlertDialog.Builder(this)
                        .setTitle("🔔 Avisos con la app cerrada")
                        .setMessage(
                            "Para recibir notificaciones cuando empiece o termine un culto en directo incluso si el móvil está bloqueado o la aplicación cerrada, te recomendamos desactivar la optimización de batería para Pan Bendito.\n\n" +
                            "¿Deseas configurarlo ahora?"
                        )
                        .setPositiveButton("Sí, configurar") { _, _ ->
                            prefs.edit().putBoolean("battery_dialog_prompted", true).apply()
                            try {
                                val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                            } catch (_: Exception) {}
                        }
                        .setNegativeButton("Ahora no") { _, _ ->
                            prefs.edit().putBoolean("battery_dialog_prompted", true).apply()
                        }
                        .setCancelable(true)
                        .show()
                }
            } catch (_: Exception) {}
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
                "getLikedPetitions" -> {
                    val prefs = getSharedPreferences("pan_bendito_prefs", Context.MODE_PRIVATE)
                    val set = prefs.getStringSet("liked_petitions", emptySet())
                    result.success(set?.toList() ?: emptyList<String>())
                }
                "saveLikedPetition" -> {
                    val id = call.argument<String>("id") ?: ""
                    val liked = call.argument<Boolean>("liked") ?: true
                    val prefs = getSharedPreferences("pan_bendito_prefs", Context.MODE_PRIVATE)
                    val current = prefs.getStringSet("liked_petitions", HashSet())?.toMutableSet() ?: HashSet()
                    if (liked) current.add(id) else current.remove(id)
                    prefs.edit().putStringSet("liked_petitions", current).apply()
                    result.success(true)
                }
                "getPendingPetitions" -> {
                    val prefs = getSharedPreferences("pan_bendito_prefs", Context.MODE_PRIVATE)
                    result.success(prefs.getString("pending_petitions_json", "[]"))
                }
                "savePendingPetitions" -> {
                    val json = call.argument<String>("json") ?: "[]"
                    val prefs = getSharedPreferences("pan_bendito_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("pending_petitions_json", json).apply()
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

            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val smallIcon = android.R.drawable.stat_notify_chat

            val builder = NotificationCompat.Builder(this, "pan_bendito_live")
                .setSmallIcon(smallIcon)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setSound(soundUri)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            try {
                val logoId = resources.getIdentifier("ic_launcher", "mipmap", packageName)
                if (logoId != 0) {
                    val bitmap = BitmapFactory.decodeResource(resources, logoId)
                    if (bitmap != null) {
                        builder.setLargeIcon(bitmap)
                    }
                }
            } catch (_: Exception) {}

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

    override fun onStop() {
        super.onStop()
        try {
            LiveNotificationService.start(this)
            NotificationScheduler.scheduleNext(this)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        try {
            NotificationScheduler.scheduleNext(this)
        } catch (_: Exception) {}
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
