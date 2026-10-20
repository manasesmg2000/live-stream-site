import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.iglesiapanbendito.directo/native');

  /// Obtiene el nombre guardado en SharedPreferences
  static Future<String?> getUserName() async {
    try {
      final name = await _channel.invokeMethod<String>('getUserName');
      return (name != null && name.trim().isNotEmpty) ? name.trim() : null;
    } catch (_) {
      return null;
    }
  }

  /// Guarda el nombre del usuario
  static Future<bool> saveUserName(String name) async {
    try {
      final success = await _channel.invokeMethod<bool>('saveUserName', {'name': name.trim()});
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Registra el acceso en el archivo de texto local
  static Future<void> logAccess(String name, String date) async {
    try {
      await _channel.invokeMethod('logAccess', {
        'name': name.trim(),
        'date': date,
      });
    } catch (_) {}
  }

  /// Muestra una notificación nativa del sistema
  static Future<void> showLiveNotification({
    String title = '🔴 ¡Estamos EN DIRECTO!',
    String body = 'Ha comenzado el culto en directo de Pan Bendito. Toca para verlo.',
  }) async {
    try {
      await _channel.invokeMethod('showLiveNotification', {
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }

  /// Abre la app oficial de YouTube con el vídeo
  static Future<bool> openYouTube(String videoId) async {
    try {
      final success = await _channel.invokeMethod<bool>('openYouTube', {
        'videoId': videoId,
      });
      return success ?? false;
    } catch (_) {
      return false;
    }
  }
}
