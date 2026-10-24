import 'dart:async';
import 'package:http/http.dart' as http;
import 'native_bridge.dart';

class PresenceService {
  static const String presenceTopicPrimary =
      'https://ntfy.projectsegfau.lt/iglesia-pan-bendito-presence-v1';
  static const String presenceTopicFallback =
      'https://ntfy.envs.net/iglesia-pan-bendito-presence-v1';

  static Timer? _heartbeatTimer;
  static String? _currentUserName;

  /// Registra el ingreso del usuario y arranca los latidos de presencia
  static Future<void> registerAndStart(String userName) async {
    _currentUserName = userName.trim();
    if (_currentUserName == null || _currentUserName!.isEmpty) return;

    final nowStr = DateTime.now().toLocal().toString().split('.').first;

    // 1. Guardar en el archivo de texto local
    await NativeBridge.logAccess(_currentUserName!, nowStr);

    // 2. Enviar evento de entrada al panel de admin
    _sendSignal('LOGIN:$_currentUserName|$nowStr');

    // 3. Iniciar latidos periódicos cada 20 segundos
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_currentUserName != null && _currentUserName!.isNotEmpty) {
        final t = DateTime.now().toLocal().toString().split('.').first;
        _sendSignal('PING:$_currentUserName|$t');
      }
    });
  }

  /// Notifica al panel que el usuario salió de la app o cerró la pantalla
  static void logout() {
    if (_currentUserName != null && _currentUserName!.isNotEmpty) {
      final t = DateTime.now().toLocal().toString().split('.').first;
      _sendSignal('LOGOUT:$_currentUserName|$t');
    }
    stop();
  }

  static void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static void _sendSignal(String message) {
    try {
      http.post(
        Uri.parse(presenceTopicPrimary),
        body: message,
      ).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 500));
      http.post(
        Uri.parse(presenceTopicFallback),
        body: message,
      ).timeout(const Duration(seconds: 2)).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }
}
