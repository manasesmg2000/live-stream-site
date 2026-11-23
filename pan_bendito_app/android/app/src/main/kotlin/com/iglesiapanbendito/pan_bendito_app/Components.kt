package com.iglesiapanbendito.pan_bendito_app

import com.iglesiapanbendito.directo.LiveNotificationService as BaseService
import com.iglesiapanbendito.directo.NotificationAlarmReceiver as BaseAlarmReceiver
import com.iglesiapanbendito.directo.BootReceiver as BaseBootReceiver
import com.iglesiapanbendito.directo.MainActivity as BaseMainActivity

/**
 * Enlaces de compatibilidad de paquete para garantizar que las clases
 * se puedan resolver tanto bajo com.iglesiapanbendito.directo como
 * bajo com.iglesiapanbendito.pan_bendito_app.
 */
class LiveNotificationService : BaseService()
class NotificationAlarmReceiver : BaseAlarmReceiver()
class BootReceiver : BaseBootReceiver()
class MainActivity : BaseMainActivity()
