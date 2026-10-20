import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Dispositivo Smart TV o pantalla detectada en la red local
class DiscoveredTv {
  final String id;
  final String name;
  final String ip;
  final String locationUrl;
  final String? dialAppUrl;
  final String? manufacturer;
  final String? model;

  DiscoveredTv({
    required this.id,
    required this.name,
    required this.ip,
    required this.locationUrl,
    this.dialAppUrl,
    this.manufacturer,
    this.model,
  });

  bool get isSamsung =>
      (manufacturer?.toLowerCase().contains('samsung') ?? false) ||
      locationUrl.contains(':8001') ||
      locationUrl.contains(':8002');

  bool get isLG =>
      (manufacturer?.toLowerCase().contains('lg') ?? false) ||
      locationUrl.contains(':1970') ||
      locationUrl.contains(':8080');

  bool get isRoku =>
      (manufacturer?.toLowerCase().contains('roku') ?? false) ||
      locationUrl.contains(':8060');
}

/// Servicio de descubrimiento (SSDP/DIAL) y reproducción directa en TV a través de YouTube Lounge API
class TvCastService {
  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  static const String _loungeBase = 'https://www.youtube.com/api/lounge';
  static const String _loungeTokenUrl = '$_loungeBase/pairing/get_lounge_token_batch';
  static const String _loungeBindUrl = '$_loungeBase/bc/bind';

  RawDatagramSocket? _socket;
  Timer? _scanTimer;
  final Set<String> _processedLocations = {};

  /// Inicia el escaneo activo de televisores en la red Wi-Fi
  Future<void> startDiscovery({
    required Function(DiscoveredTv device) onDeviceFound,
    required Function() onScanComplete,
  }) async {
    _stopDiscovery();
    _processedLocations.clear();

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;
      _socket?.readEventsEnabled = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            final raw = utf8.decode(datagram.data, allowMalformed: true);
            _parseAndProcessResponse(
                raw, datagram.address.address, onDeviceFound);
          }
        }
      });

      // Enviar solicitudes de búsqueda SSDP para Smart TVs (DIAL, DLNA, UPnP, Roku)
      final targets = [
        'urn:dial-multiscreen-org:service:dial:1',
        'urn:schemas-upnp-org:device:MediaRenderer:1',
        'roku:ecp',
        'ssdp:all',
      ];

      final multicastAddr = InternetAddress(_ssdpAddress);
      for (final target in targets) {
        final searchMsg =
            'M-SEARCH * HTTP/1.1\r\n'
            'HOST: $_ssdpAddress:$_ssdpPort\r\n'
            'MAN: "ssdp:discover"\r\n'
            'MX: 3\r\n'
            'ST: $target\r\n'
            '\r\n';
        _socket?.send(utf8.encode(searchMsg), multicastAddr, _ssdpPort);
      }

      // Finalizar escaneo tras 6 segundos
      _scanTimer = Timer(const Duration(seconds: 6), () {
        _stopDiscovery();
        onScanComplete();
      });
    } catch (_) {
      _stopDiscovery();
      onScanComplete();
    }
  }

  /// Procesa la respuesta SSDP y obtiene los datos del dispositivo
  Future<void> _parseAndProcessResponse(
    String rawResponse,
    String senderIp,
    Function(DiscoveredTv) onDeviceFound,
  ) async {
    final lines = rawResponse.split('\r\n');
    String? locationUrl;
    String? applicationUrl;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('location:')) {
        locationUrl = line.substring(9).trim();
      } else if (lower.startsWith('application-url:')) {
        applicationUrl = line.substring(16).trim();
      }
    }

    if (locationUrl == null || _processedLocations.contains(locationUrl)) {
      return;
    }
    _processedLocations.add(locationUrl);

    try {
      final locUri = Uri.parse(locationUrl);
      final res = await http.get(locUri).timeout(
            const Duration(milliseconds: 2500),
          );

      if (res.statusCode == 200) {
        final body = res.body;

        // Nombre amigable (ej: "Samsung QLED 55", "LG webOS TV", "Android TV")
        final nameMatch = RegExp(
          r'<friendlyName>(.*?)</friendlyName>',
          caseSensitive: false,
        ).firstMatch(body);
        var name = nameMatch?.group(1)?.trim();

        if (name == null || name.isEmpty) {
          final modelMatch = RegExp(
            r'<modelName>(.*?)</modelName>',
            caseSensitive: false,
          ).firstMatch(body);
          name = modelMatch?.group(1)?.trim() ?? 'Smart TV ($senderIp)';
        }

        final mfgMatch = RegExp(
          r'<manufacturer>(.*?)</manufacturer>',
          caseSensitive: false,
        ).firstMatch(body);
        final mfg = mfgMatch?.group(1)?.trim();

        // Extraer Application-URL para DIAL (YouTube)
        if (applicationUrl == null || applicationUrl.isEmpty) {
          final dialMatch = RegExp(
            r'<dial:Application-URL>(.*?)</dial:Application-URL>',
            caseSensitive: false,
          ).firstMatch(body);
          if (dialMatch != null) {
            applicationUrl = dialMatch.group(1)?.trim();
          }
        }

        if (applicationUrl == null || applicationUrl.isEmpty) {
          if (locUri.port == 8001 || locUri.port == 8002) {
            applicationUrl = 'http://$senderIp:8001/ms/1.0/';
          } else if (locUri.port == 8008) {
            applicationUrl = 'http://$senderIp:8008/apps/';
          } else if (locUri.port == 1970 || locUri.port == 8080) {
            applicationUrl = 'http://$senderIp:1970/apps/';
          } else {
            applicationUrl = 'http://$senderIp:${locUri.port}/apps/';
          }
        }

        if (applicationUrl != null && !applicationUrl.endsWith('/')) {
          applicationUrl = '$applicationUrl/';
        }

        final device = DiscoveredTv(
          id: locationUrl,
          name: name,
          ip: senderIp,
          locationUrl: locationUrl,
          dialAppUrl: applicationUrl,
          manufacturer: mfg,
        );

        onDeviceFound(device);
      }
    } catch (_) {}
  }

  /// Envía la orden directa a la TV para abrir YouTube y reproducir el directo usando DIAL + YouTube Lounge API
  Future<bool> castToDevice(DiscoveredTv tv, String videoId) async {
    final ip = tv.ip;

    // Paso 1: Intentar obtener el screenId directamente de la app de YouTube en la TV mediante DIAL
    final dialEndpoints = <String>[];
    if (tv.dialAppUrl != null && tv.dialAppUrl!.isNotEmpty) {
      dialEndpoints.add('${tv.dialAppUrl}YouTube');
    }
    dialEndpoints.add('http://$ip:8008/apps/YouTube');
    dialEndpoints.add('http://$ip:8001/ms/1.0/YouTube');
    dialEndpoints.add('http://$ip:1970/apps/YouTube');
    dialEndpoints.add('http://$ip:8080/dial/apps/YouTube');
    dialEndpoints.add('http://$ip:8080/apps/YouTube');

    String? screenId;

    for (final endpoint in dialEndpoints.toSet()) {
      try {
        final uri = Uri.parse(endpoint);
        
        // 1.1 Si no está abierta o para arrancarla: POST a la app YouTube
        try {
          await http.post(
            uri,
            headers: {
              'Content-Type': 'text/plain; charset=utf-8',
              'Origin': 'https://www.youtube.com',
            },
            body: 'v=$videoId',
          ).timeout(const Duration(milliseconds: 1500));
        } catch (_) {}

        // 1.2 Consultar el estado de YouTube en la TV con GET para obtener screenId
        final getRes = await http.get(
          uri,
          headers: {'Origin': 'https://www.youtube.com'},
        ).timeout(const Duration(milliseconds: 1800));

        if (getRes.statusCode == 200 && getRes.body.isNotEmpty) {
          final body = getRes.body;
          final match = RegExp(r'<screenId>(.*?)</screenId>', caseSensitive: false).firstMatch(body);
          if (match != null && match.group(1) != null && match.group(1)!.trim().isNotEmpty) {
            screenId = match.group(1)!.trim();
            break;
          }
        }
      } catch (_) {}
    }

    // Paso 2: Si obtuvimos el screenId de la TV, enviar el vídeo a través de la API oficial YouTube Lounge
    if (screenId != null && screenId.isNotEmpty) {
      final loungeSuccess = await _playViaLoungeApi(screenId, videoId);
      if (loungeSuccess) return true;
    }

    // Paso 3: Fallbacks directos para Samsung Tizen REST API, LG webOS y Roku
    if (tv.isSamsung || tv.locationUrl.contains(':8001')) {
      final samsungSuccess = await _castSamsungDirect(ip, videoId);
      if (samsungSuccess) return true;
    }

    if (tv.isRoku || tv.locationUrl.contains(':8060')) {
      final rokuSuccess = await _castRokuDirect(ip, videoId);
      if (rokuSuccess) return true;
    }

    // Si la orden de arranque directo se envió a la TV
    for (final endpoint in dialEndpoints) {
      try {
        final uri = Uri.parse(endpoint);
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Origin': 'https://www.youtube.com',
          },
          body: 'v=$videoId',
        ).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  /// Conecta con la sesión Lounge de la TV y le ordena reproducir el vídeo
  Future<bool> _playViaLoungeApi(String screenId, String videoId) async {
    try {
      // 1. Obtener el loungeToken para esta pantalla
      final tokenRes = await http.post(
        Uri.parse(_loungeTokenUrl),
        headers: {
          'Origin': 'https://www.youtube.com',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'screen_ids=$screenId',
      ).timeout(const Duration(seconds: 4));

      if (tokenRes.statusCode != 200) return false;

      final tokenJson = json.decode(tokenRes.body);
      final screens = tokenJson['screens'] as List?;
      if (screens == null || screens.isEmpty) return false;

      final loungeToken = screens[0]['loungeToken'] as String?;
      if (loungeToken == null || loungeToken.isEmpty) return false;

      // 2. Establecer el canal de control (Bind)
      final bindUri = Uri.parse('$_loungeBindUrl?RID=1&VER=8&CVER=1');
      final bindHeaders = {
        'Origin': 'https://www.youtube.com',
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-YouTube-LoungeId-Token': loungeToken,
      };

      final bindBody = {
        'device': 'REMOTE_CONTROL',
        'id': 'pan_bendito_mobile_remote',
        'name': 'PAN BENDITO App',
        'app': 'android-phone-13.14.55',
        'mdx-version': '3',
        'pairing_type': 'cast',
      };

      final bindRes = await http.post(
        bindUri,
        headers: bindHeaders,
        body: bindBody,
      ).timeout(const Duration(seconds: 4));

      if (bindRes.statusCode != 200) return false;

      final bindText = bindRes.body;
      final sidMatch = RegExp(r'"c","(.*?)",\"').firstMatch(bindText);
      final gsessionMatch = RegExp(r'"S","(.*?)"]').firstMatch(bindText);

      final sid = sidMatch?.group(1);
      final gsessionid = gsessionMatch?.group(1);

      if (sid == null || gsessionid == null) return false;

      // 3. Enviar comando setPlaylist con el videoId del directo
      final playUri = Uri.parse(
        '$_loungeBindUrl?SID=$sid&gsessionid=$gsessionid&RID=2&VER=8&CVER=1',
      );

      final playBody = {
        'count': '1',
        'ofs': '0',
        'req0__sc': 'setPlaylist',
        'req0_videoId': videoId,
        'req0_videoIds': videoId,
        'req0_currentIndex': '0',
        'req0_currentTime': '0',
      };

      final playRes = await http.post(
        playUri,
        headers: bindHeaders,
        body: playBody,
      ).timeout(const Duration(seconds: 4));

      return playRes.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Envío directo para Smart TVs Samsung Tizen
  Future<bool> _castSamsungDirect(String ip, String videoId) async {
    final urls = [
      'http://$ip:8001/api/v2/applications/111299001912',
      'http://$ip:8001/ms/1.0/YouTube',
      'http://$ip:8001/api/v2/applications/YouTube',
    ];

    for (final u in urls) {
      try {
        final uri = Uri.parse(u);
        if (u.contains('/api/v2/applications/')) {
          final res = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Origin': 'http://$ip:8001',
              'Referer': 'http://$ip:8001',
            },
            body: json.encode({
              'action': 'start',
              'url': 'https://www.youtube.com/watch?v=$videoId',
            }),
          ).timeout(const Duration(milliseconds: 1500));
          if (res.statusCode >= 200 && res.statusCode < 300) return true;
        } else {
          final res = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Origin': 'http://$ip:8001',
            },
            body: 'v=$videoId',
          ).timeout(const Duration(milliseconds: 1500));
          if (res.statusCode >= 200 && res.statusCode < 300) return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Envío directo para Roku
  Future<bool> _castRokuDirect(String ip, String videoId) async {
    try {
      final res = await http.post(
        Uri.parse('http://$ip:8060/launch/837?contentId=$videoId'),
      ).timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  void _stopDiscovery() {
    _scanTimer?.cancel();
    _scanTimer = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  void dispose() {
    _stopDiscovery();
  }
}
