import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:android_intent_plus/android_intent.dart';

/// Representa un televisor o pantalla detectada en la red local
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

/// Servicio de descubrimiento y transmisión a televisores (Smart TV, DLNA, DIAL, Cast)
class TvCastService {
  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

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

      // Finalizar escaneo tras 5 segundos
      _scanTimer = Timer(const Duration(seconds: 5), () {
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
            const Duration(milliseconds: 2000),
          );

      if (res.statusCode == 200) {
        final body = res.body;

        // Nombre amigable (ej: "Samsung QLED 55", "LG webOS TV", "Roku Ultra")
        final nameMatch = RegExp(
          r'<friendlyName>(.*?)</friendlyName>',
          caseSensitive: false,
        ).firstMatch(body);
        var name = nameMatch?.group(1)?.trim();

        // Si no hay friendlyName, intentar con modelName
        if (name == null || name.isEmpty) {
          final modelMatch = RegExp(
            r'<modelName>(.*?)</modelName>',
            caseSensitive: false,
          ).firstMatch(body);
          name = modelMatch?.group(1)?.trim() ?? 'Smart TV ($senderIp)';
        }

        // Fabricante
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

        // Si applicationUrl es null, deducir según puerto y fabricante
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
    } catch (_) {
      // Ignorar dispositivos que no responden al XML
    }
  }

  /// Envía la orden directa a la Smart TV para abrir YouTube y reproducir el directo
  Future<bool> castToDevice(DiscoveredTv tv, String videoId) async {
    final candidates = <String>[];
    final ip = tv.ip;

    // 1. DIAL App URL explícito detectado en SSDP
    if (tv.dialAppUrl != null && tv.dialAppUrl!.isNotEmpty) {
      final base = tv.dialAppUrl!;
      candidates.add('${base}YouTube');
      candidates.add('${base}111299001912'); // Samsung YouTube App ID
      candidates.add('${base}youtube.leanback.v4'); // LG YouTube App ID
    }

    // 2. Variantes de Samsung Tizen (puertos 8001 y 8002)
    candidates.add('http://$ip:8001/ms/1.0/YouTube');
    candidates.add('http://$ip:8001/api/v2/applications/111299001912');
    candidates.add('http://$ip:8001/api/v2/applications/YouTube');
    candidates.add('http://$ip:8001/api/v2/applications/org.tizen.browser');
    candidates.add('http://$ip:8002/ms/1.0/YouTube');

    // 3. Variantes de LG webOS (puertos 1970, 8080, 3000)
    candidates.add('http://$ip:1970/apps/YouTube');
    candidates.add('http://$ip:8080/dial/apps/YouTube');
    candidates.add('http://$ip:8080/apps/YouTube');
    candidates.add('http://$ip:3000/apps/YouTube');

    // 4. Roku ECP (puerto 8060)
    candidates.add('http://$ip:8060/launch/837?contentId=$videoId');
    candidates.add('http://$ip:8060/input/837?contentId=$videoId');

    // 5. Android TV / Google Cast DIAL (puerto 8008)
    candidates.add('http://$ip:8008/apps/YouTube');
    candidates.add('http://$ip:8008/apps/111299001912');

    // 6. Basado en locationUrl
    final locUri = Uri.tryParse(tv.locationUrl);
    if (locUri != null && locUri.hasPort) {
      candidates.add('${locUri.scheme}://${locUri.host}:${locUri.port}/apps/YouTube');
    }

    final uniqueCandidates = candidates.toSet().toList();

    for (final candidate in uniqueCandidates) {
      try {
        final uri = Uri.parse(candidate);

        // A. Si es Roku ECP
        if (candidate.contains(':8060/')) {
          final res = await http.post(uri).timeout(const Duration(milliseconds: 1500));
          if (res.statusCode == 200 || res.statusCode == 204) return true;
          continue;
        }

        // B. Si es Samsung REST API
        if (candidate.contains('/api/v2/applications/')) {
          final originHeader = 'http://$ip:8001';
          final bodies = [
            json.encode({'action': 'start', 'url': 'https://www.youtube.com/watch?v=$videoId'}),
            json.encode({'data': {'url': 'https://www.youtube.com/watch?v=$videoId'}}),
            json.encode({'action': 'start'}),
          ];
          for (final bodyJson in bodies) {
            try {
              final res = await http.post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Origin': originHeader,
                  'Referer': originHeader,
                },
                body: bodyJson,
              ).timeout(const Duration(milliseconds: 1500));
              if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 202) {
                return true;
              }
            } catch (_) {}
          }
        }

        // C. DIAL POST estándar (text/plain y form-urlencoded con Origin)
        final origin = 'http://$ip:${uri.port > 0 ? uri.port : 80}';
        final headersList = [
          {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Origin': 'https://www.youtube.com',
          },
          {
            'Content-Type': 'text/plain; charset=utf-8',
            'Origin': origin,
          },
          {
            'Content-Type': 'text/plain; charset=utf-8',
          },
        ];

        for (final hdrs in headersList) {
          try {
            final res = await http.post(
              uri,
              headers: hdrs,
              body: 'v=$videoId',
            ).timeout(const Duration(milliseconds: 1500));

            if (res.statusCode >= 200 && res.statusCode < 300) {
              return true;
            }
          } catch (_) {}
        }

        // D. Intento con parámetro query en URL
        final uriWithQuery = uri.replace(queryParameters: {'v': videoId});
        final resQuery = await http.post(
          uriWithQuery,
          headers: {'Content-Type': 'text/plain; charset=utf-8', 'Origin': origin},
          body: 'v=$videoId',
        ).timeout(const Duration(milliseconds: 1500));

        if (resQuery.statusCode >= 200 && resQuery.statusCode < 300) {
          return true;
        }
      } catch (_) {
        // Seguir probando el siguiente endpoint
      }
    }

    return false;
  }

  /// Abre directamente el panel de búsqueda de dispositivos Cast nativo del sistema
  Future<bool> openSystemCastSettings() async {
    if (Platform.isAndroid) {
      try {
        // 1. Selector estándar de Google Cast / Pantallas inalámbricas
        const intent = AndroidIntent(
          action: 'android.settings.CAST_SETTINGS',
        );
        await intent.launch();
        return true;
      } catch (_) {
        try {
          // 2. Fallback para Wi-Fi Display / Miracast
          const intent = AndroidIntent(
            action: 'android.settings.WIFI_DISPLAY_SETTINGS',
          );
          await intent.launch();
          return true;
        } catch (_) {
          try {
            // 3. Fallback a ajustes generales
            const intent = AndroidIntent(
              action: 'android.settings.SETTINGS',
            );
            await intent.launch();
            return true;
          } catch (_) {
            return false;
          }
        }
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
