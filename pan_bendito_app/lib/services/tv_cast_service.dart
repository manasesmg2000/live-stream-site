import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Dispositivo Smart TV detectado en la red local mediante SSDP
class DiscoveredTv {
  final String ip;
  final String name;
  final String locationUrl;
  final String? dialAppUrl;

  DiscoveredTv({
    required this.ip,
    required this.name,
    required this.locationUrl,
    this.dialAppUrl,
  });
}

/// Servicio DIAL para descubrir la IP de la TV y lanzar el directo
class TvCastService {
  static const String _multicastAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  RawDatagramSocket? _socket;
  Timer? _scanTimer;
  final Set<String> _foundIps = {};

  /// Descubre la IP de la primera tele compatible encontrada en la red Wi-Fi
  static Future<String?> discoverFirstTvIp({Duration timeout = const Duration(seconds: 4)}) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final searchMessage =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: urn:dial-multiscreen-org:service:dial:1\r\n\r\n';

      socket.send(
        utf8.encode(searchMessage),
        InternetAddress(_multicastAddress),
        _ssdpPort,
      );

      final completer = Completer<String?>();

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null && !completer.isCompleted) {
            final ip = datagram.address.address;
            completer.complete(ip);
          }
        }
      });

      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      final result = await completer.future;
      socket.close();
      return result;
    } catch (_) {
      try {
        socket?.close();
      } catch (_) {}
      return null;
    }
  }

  /// Escanea y lista todos los televisores conectados a la misma Wi-Fi
  Future<void> startDiscovery({
    required Function(DiscoveredTv device) onDeviceFound,
    required Function() onScanComplete,
  }) async {
    _stopDiscovery();
    _foundIps.clear();

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            final senderIp = datagram.address.address;
            final raw = utf8.decode(datagram.data, allowMalformed: true);
            _processSsdpResponse(raw, senderIp, onDeviceFound);
          }
        }
      });

      final searchMessage =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: urn:dial-multiscreen-org:service:dial:1\r\n\r\n';

      final encoded = utf8.encode(searchMessage);
      final multicast = InternetAddress(_multicastAddress);
      
      // Enviar ráfaga de descubrimiento
      _socket?.send(encoded, multicast, _ssdpPort);
      Timer(const Duration(milliseconds: 600), () {
        _socket?.send(encoded, multicast, _ssdpPort);
      });

      _scanTimer = Timer(const Duration(seconds: 5), () {
        _stopDiscovery();
        onScanComplete();
      });
    } catch (_) {
      _stopDiscovery();
      onScanComplete();
    }
  }

  Future<void> _processSsdpResponse(
    String response,
    String ip,
    Function(DiscoveredTv) onDeviceFound,
  ) async {
    if (_foundIps.contains(ip)) return;
    _foundIps.add(ip);

    final lines = response.split('\r\n');
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

    String tvName = 'Smart TV ($ip)';

    if (locationUrl != null && locationUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(locationUrl)).timeout(
              const Duration(seconds: 2),
            );
        if (res.statusCode == 200) {
          final body = res.body;
          final match = RegExp(r'<friendlyName>(.*?)</friendlyName>', caseSensitive: false)
              .firstMatch(body);
          if (match != null && match.group(1) != null) {
            tvName = match.group(1)!.trim();
          }

          if (applicationUrl == null || applicationUrl.isEmpty) {
            final appMatch = RegExp(r'<dial:Application-URL>(.*?)</dial:Application-URL>', caseSensitive: false)
                .firstMatch(body);
            if (appMatch != null && appMatch.group(1) != null) {
              applicationUrl = appMatch.group(1)!.trim();
            }
          }
        }
      } catch (_) {}
    }

    onDeviceFound(
      DiscoveredTv(
        ip: ip,
        name: tvName,
        locationUrl: locationUrl ?? '',
        dialAppUrl: applicationUrl,
      ),
    );
  }

  /// Lanza el vídeo directamente en la app de YouTube de la Smart TV mediante petición DIAL POST
  static Future<bool> launchYouTubeOnTv(String tvIp, String videoId, {String? customAppUrl}) async {
    final urls = <String>[];

    // 1. URL DIAL exacta si vino en las cabeceras SSDP
    if (customAppUrl != null && customAppUrl.isNotEmpty) {
      final base = customAppUrl.endsWith('/') ? customAppUrl : '$customAppUrl/';
      urls.add('${base}YouTube');
    }

    // 2. Puerto 8008 estándar de DIAL (Chromecast, Android TV, Google TV, Smart TVs)
    urls.add('http://$tvIp:8008/apps/YouTube');

    // 3. Puertos habituales de fabricantes (Samsung 8001, LG 1970/8080)
    urls.add('http://$tvIp:8001/ms/1.0/YouTube');
    urls.add('http://$tvIp:1970/apps/YouTube');
    urls.add('http://$tvIp:8080/dial/apps/YouTube');
    urls.add('http://$tvIp:8080/apps/YouTube');

    for (final endpoint in urls.toSet()) {
      try {
        final url = Uri.parse(endpoint);

        // Envío DIAL estándar con Content-Type text/plain y body v=videoId
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Origin': 'https://www.youtube.com',
          },
          body: 'v=$videoId',
        ).timeout(const Duration(seconds: 3));

        // 201 Created (o 200 OK / 202 Accepted / 204 No Content) indican éxito de lanzamiento
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }

        // Reintento con query parameter ?v=videoId
        final queryUrl = url.replace(queryParameters: {'v': videoId});
        final queryResponse = await http.post(
          queryUrl,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Origin': 'https://www.youtube.com',
          },
          body: 'v=$videoId',
        ).timeout(const Duration(seconds: 3));

        if (queryResponse.statusCode >= 200 && queryResponse.statusCode < 300) {
          return true;
        }
      } catch (_) {
        // Continuar probando los demás puertos si uno no responde
      }
    }

    return false;
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
