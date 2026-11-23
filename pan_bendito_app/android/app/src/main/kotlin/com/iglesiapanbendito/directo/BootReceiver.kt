package com.iglesiapanbendito.directo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

open class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON") {
            try {
                // Arrancar el servicio de monitoreo en primer plano y programar alarmas periódicas
                LiveNotificationService.start(context)
                NotificationScheduler.scheduleNext(context)
            } catch (_: Exception) {}
        }
    }
}
