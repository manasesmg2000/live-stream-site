import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stream_state.dart';
import 'native_bridge.dart';

class StreamService {
  static const String githubApiUrl =
      'https://api.github.com/repos/manasesmg2000/live-stream-site/contents/config.json?ref=main';
  static const String fallbackPagesUrl =
      'https://manasesmg2000.github.io/live-stream-site/config.json';
  static const String realtimeTopic =
      'https://ntfy.sh/iglesia-pan-bendito-live-channel-v1';

  final _stateController = StreamController<StreamState>.broadcast();
  Stream<StreamState> get stateStream => _stateController.stream;

  StreamState _currentState = StreamState.offline();
  StreamState get currentState => _currentState;

  Timer? _pollingTimer;
  http.Client? _sseClient;
  bool _initialCheckDone = false;

  void start() {
    // 1. Obtener estado inicial
    fetchState();

    // 2. Conectar al canal en tiempo real (SSE)
    _connectRealtime();

    // 3. Comprobación periódica de respaldo cada 12 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      fetchState();
    });
  }

  void stop() {
    _pollingTimer?.cancel();
    _sseClient?.close();
    _stateController.close();
  }

  Future<void> fetchState() async {
    StreamState? state;

    // Intentar GitHub API directa en tiempo real
    try {
      final uri = Uri.parse('$githubApiUrl&_t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri, headers: {
        'Accept': 'application/vnd.github.v3.raw',
        'Cache-Control': 'no-cache',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        state = StreamState.fromJson(data);
      }
    } catch (_) {}

    // Fallback a GitHub Pages
    if (state == null) {
      try {
        final uri = Uri.parse('$fallbackPagesUrl?_t=${DateTime.now().millisecondsSinceEpoch}');
        final res = await http.get(uri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          state = StreamState.fromJson(data);
        }
      } catch (_) {}
    }

    if (state != null) {
      _emitState(state);
    }
  }

  void _connectRealtime() async {
    try {
      _sseClient?.close();
      _sseClient = http.Client();
      final request = http.Request('GET', Uri.parse('$realtimeTopic/sse'));
      final response = await _sseClient!.send(request);

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          try {
            final data = json.decode(jsonStr);
            if (data['event'] == 'message' && data['message'] != null) {
              _handleSignal(data['message'].toString());
            }
          } catch (_) {}
        }
      }, onError: (_) {
        Future.delayed(const Duration(seconds: 5), _connectRealtime);
      }, onDone: () {
        Future.delayed(const Duration(seconds: 5), _connectRealtime);
      });
    } catch (_) {}
  }

  void _handleSignal(String msg) {
    msg = msg.trim();
    if (msg.startsWith('LIVE:')) {
      final parts = msg.substring(5).split('|');
      final vid = extractVideoId(parts[0]);
      final lastVid = parts.length > 1 ? extractVideoId(parts[1]) : _currentState.lastVideoId;
      _emitState(StreamState(isLive: true, videoId: vid, lastVideoId: lastVid));
    } else if (msg.startsWith('OFFLINE')) {
      final parts = msg.split('|');
      final lastVid = parts.length > 1 ? extractVideoId(parts[1]) : (_currentState.videoId.isNotEmpty ? _currentState.videoId : _currentState.lastVideoId);
      _emitState(StreamState.offline(lastVideoId: lastVid));
    }
  }

  void _emitState(StreamState newState) {
    if (newState.isLive == _currentState.isLive &&
        newState.videoId == _currentState.videoId &&
        newState.lastVideoId == _currentState.lastVideoId) {
      return;
    }

    final wasLive = _currentState.isLive;
    final wasOffline = !_currentState.isLive;
    final isNowLive = newState.isLive && newState.videoId.isNotEmpty;
    final isNowOffline = !newState.isLive;

    _currentState = newState;
    _stateController.add(_currentState);

    // Si pasa de offline a live, emitir notificación de inicio
    if (isNowLive && (wasOffline || !_initialCheckDone)) {
      NativeBridge.showLiveNotification(
        title: '🔴 ¡Estamos EN DIRECTO!',
        body: 'Ha comenzado el culto en directo de Pan Bendito. Toca para verlo.',
      );
    }
    // Si pasa de live a offline, emitir notificación de finalización
    else if (isNowOffline && wasLive && _initialCheckDone) {
      NativeBridge.showLiveNotification(
        title: '⏹ Culto finalizado',
        body: 'El directo ha terminado. ¡Gracias por acompañarnos! Ya puedes ver el culto anterior.',
      );
    }
    _initialCheckDone = true;
  }

  static String extractVideoId(String input) {
    input = input.trim();
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(input)) {
      return input;
    }
    final patterns = [
      RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'embed\/([a-zA-Z0-9_-]{11})'),
      RegExp(r'live\/([a-zA-Z0-9_-]{11})'),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(input);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)!;
      }
    }
    return input;
  }
}
