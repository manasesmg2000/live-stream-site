import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Dispositivo Smart TV detectado en la red local mediante SSDP o sondeo de red
class DiscoveredTv {
  final String ip;
  final String name;
  final String locationUrl;
  final String? dialAppUrl;
  final bool isManual;

  DiscoveredTv({
    required this.ip,
    required this.name,
    required this.locationUrl,
    this.dialAppUrl,
    this.isManual = false,
  });
}

/// Servicio DIAL para descubrir la IP de la TV y lanzar el directo
class TvCastService {
  static const String _multicastAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  RawDatagramSocket? _socket;
  Timer? _scanTimer;
  final Set<String> _foundIps = {};
  static final List<DiscoveredTv> _savedDevices = [];

  /// Lista de dispositivos guardados manualmente o de sesiones anteriores
  static List<DiscoveredTv> get savedDevices => List.unmodifiable(_savedDevices);

  /// Guarda una TV manualmente por IP
  static void addSavedDevice(DiscoveredTv tv) {
    _savedDevices.removeWhere((d) => d.ip == tv.ip);
    _savedDevices.insert(0, tv);
  }

  /// Obtiene la IP local del teléfono en la red Wi-Fi
  static Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal && addr.address.contains('.')) {
            final ip = addr.address;
            if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
              return ip;
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Descubre la IP de la primera tele compatible encontrada en la red Wi-Fi
  static Future<String?> discoverFirstTvIp({Duration timeout = const Duration(seconds: 4)}) async {
    if (_savedDevices.isNotEmpty) {
      return _savedDevices.first.ip;
    }

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      const searchMessage =
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

    // Notificar inmediatamente los dispositivos guardados previamente
    for (final saved in _savedDevices) {
      _foundIps.add(saved.ip);
      onDeviceFound(saved);
    }

    // 1. Escaneo SSDP Multicast (con múltiples Service Targets: dial, ssdp:all, upnp)
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          try {
            final datagram = _socket?.receive();
            if (datagram != null) {
              final senderIp = datagram.address.address;
              final raw = utf8.decode(datagram.data, allowMalformed: true);
              _processSsdpResponse(raw, senderIp, onDeviceFound);
            }
          } catch (_) {}
        }
      });

      final targets = [
        'urn:dial-multiscreen-org:service:dial:1',
        'urn:schemas-upnp-org:device:MediaRenderer:1',
        'ssdp:all',
      ];

      final multicast = InternetAddress(_multicastAddress);

      for (final st in targets) {
        final searchMsg =
            'M-SEARCH * HTTP/1.1\r\n'
            'HOST: 239.255.255.250:1900\r\n'
            'MAN: "ssdp:discover"\r\n'
            'MX: 2\r\n'
            'ST: $st\r\n\r\n';
        final encoded = utf8.encode(searchMsg);
        try {
          _socket?.send(encoded, multicast, _ssdpPort);
        } catch (_) {}
      }

      // Ráfaga secundaria tras 500ms
      Timer(const Duration(milliseconds: 500), () {
        for (final st in targets) {
          final searchMsg =
              'M-SEARCH * HTTP/1.1\r\n'
              'HOST: 239.255.255.250:1900\r\n'
              'MAN: "ssdp:discover"\r\n'
              'MX: 2\r\n'
              'ST: $st\r\n\r\n';
          try {
            _socket?.send(utf8.encode(searchMsg), multicast, _ssdpPort);
          } catch (_) {}
        }
      });
    } catch (_) {
      // Si el socket multicast falla por restricción del sistema, el sondeo unicast continuará
    }

    // 2. Sondeo Unicast LAN por puerto 8008/8001 (funciona aunque el router bloquee Multicast)
    _probeSubnetFast(onDeviceFound);

    _scanTimer = Timer(const Duration(seconds: 6), () {
      _stopDiscovery();
      onScanComplete();
    });
  }

  /// Sondeo rápido unicast de la subred local para saltar el aislamiento multicast del router
  Future<void> _probeSubnetFast(Function(DiscoveredTv) onDeviceFound) async {
    final localIp = await getLocalIp();
    if (localIp == null) return;

    final parts = localIp.split('.');
    if (parts.length != 4) return;
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
    final myHostNum = int.tryParse(parts[3]) ?? 0;

    // Probar las IPs más comunes de Smart TVs y dispositivos en la LAN
    final hostsToProbe = <int>[];
    for (int i = 2; i <= 50; i++) {
      if (i != myHostNum) hostsToProbe.add(i);
    }
    // Añadir IPs cercanas a la del móvil
    for (int i = myHostNum - 5; i <= myHostNum + 5; i++) {
      if (i > 1 && i < 255 && i != myHostNum && !hostsToProbe.contains(i)) {
        hostsToProbe.add(i);
      }
    }

    // Probar en lotes de 10 peticiones concurrentes
    const batchSize = 10;
    for (int i = 0; i < hostsToProbe.length; i += batchSize) {
      if (_socket == null && _scanTimer == null) break; // si ya terminó
      final end = (i + batchSize < hostsToProbe.length) ? i + batchSize : hostsToProbe.length;
      final batch = hostsToProbe.sublist(i, end);

      await Future.wait(batch.map((h) async {
        final targetIp = '$prefix$h';
        if (_foundIps.contains(targetIp)) return;
        await _checkTvAtIp(targetIp, onDeviceFound);
      }));
    }
  }

  /// Verifica si una IP tiene un servicio DIAL activo en los puertos estándar
  static Future<DiscoveredTv?> checkIp(String ip) async {
    try {
      // 1. Probar DIAL puerto 8008
      final url8008 = Uri.parse('http://$ip:8008/ssdp/device-desc.xml');
      try {
        final res = await http.get(url8008).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          final name = _extractNameFromXml(res.body) ?? 'Smart TV / Android TV ($ip)';
          return DiscoveredTv(
            ip: ip,
            name: name,
            locationUrl: url8008.toString(),
            dialAppUrl: 'http://$ip:8008/apps/',
            isManual: true,
          );
        }
      } catch (_) {}

      // 2. Probar si el endpoint de YouTube responde en 8008
      final urlYt = Uri.parse('http://$ip:8008/apps/YouTube');
      try {
        final res = await http.get(urlYt).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200 || res.statusCode == 404 || res.statusCode == 503) {
          return DiscoveredTv(
            ip: ip,
            name: 'Smart TV ($ip)',
            locationUrl: '',
            dialAppUrl: 'http://$ip:8008/apps/',
            isManual: true,
          );
        }
      } catch (_) {}

      // 3. Probar Samsung Tizen puerto 8001
      final url8001 = Uri.parse('http://$ip:8001/api/v2/');
      try {
        final res = await http.get(url8001).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          return DiscoveredTv(
            ip: ip,
            name: 'Samsung Smart TV ($ip)',
            locationUrl: '',
            dialAppUrl: 'http://$ip:8001/ms/1.0/',
            isManual: true,
          );
        }
      } catch (_) {}

      // Retorno con la IP como TV personalizada
      return DiscoveredTv(
        ip: ip,
        name: 'Smart TV ($ip)',
        locationUrl: '',
        dialAppUrl: 'http://$ip:8008/apps/',
        isManual: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkTvAtIp(String targetIp, Function(DiscoveredTv) onDeviceFound) async {
    try {
      final res = await http.get(
        Uri.parse('http://$targetIp:8008/ssdp/device-desc.xml'),
      ).timeout(const Duration(milliseconds: 900));

      if (res.statusCode == 200) {
        if (_foundIps.contains(targetIp)) return;
        _foundIps.add(targetIp);
        final name = _extractNameFromXml(res.body) ?? 'Smart TV ($targetIp)';
        onDeviceFound(
          DiscoveredTv(
            ip: targetIp,
            name: name,
            locationUrl: 'http://$targetIp:8008/ssdp/device-desc.xml',
            dialAppUrl: 'http://$targetIp:8008/apps/',
          ),
        );
      }
    } catch (_) {}
  }

  static String? _extractNameFromXml(String xml) {
    final match = RegExp(r'<friendlyName>(.*?)</friendlyName>', caseSensitive: false)
        .firstMatch(xml);
    return match?.group(1)?.trim();
  }

  Future<void> _processSsdpResponse(
    String response,
    String ip,
    Function(DiscoveredTv) onDeviceFound,
  ) async {
    if (_foundIps.contains(ip)) return;

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

    _foundIps.add(ip);
    String tvName = 'Smart TV ($ip)';

    if (locationUrl != null && locationUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(locationUrl)).timeout(
              const Duration(seconds: 2),
            );
        if (res.statusCode == 200) {
          final body = res.body;
          final extracted = _extractNameFromXml(body);
          if (extracted != null && extracted.isNotEmpty) {
            tvName = extracted;
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

        // Envío DIAL estándar con Content-Type text/plain; charset=utf-8 y body v=videoId
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
