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
  final String? dialAppUrl;
  final String? manufacturer;
  final String? model;

  DiscoveredTv({
    required this.id,
    required this.name,
    required this.ip,
    this.dialAppUrl,
    this.manufacturer,
    this.model,
  });

  bool get supportsDirectLaunch => dialAppUrl != null && dialAppUrl!.isNotEmpty;
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
            _parseAndProcessResponse(raw, datagram.address.address, onDeviceFound);
          }
        }
      });

      // Enviar solicitudes de búsqueda SSDP para Smart TVs (DIAL, DLNA, UPnP)
      final targets = [
        'urn:dial-multiscreen-org:service:dial:1',
        'urn:schemas-upnp-org:device:MediaRenderer:1',
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
      final res = await http.get(Uri.parse(locationUrl)).timeout(
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

        // Si applicationUrl no termina con barra, normalizar
        if (applicationUrl != null && !applicationUrl.endsWith('/')) {
          applicationUrl = '$applicationUrl/';
        }

        final device = DiscoveredTv(
          id: locationUrl,
          name: name,
          ip: senderIp,
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
    if (tv.dialAppUrl != null && tv.dialAppUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse('${tv.dialAppUrl}YouTube');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'v=$videoId',
        ).timeout(const Duration(seconds: 4));

        return response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204;
      } catch (_) {
        return false;
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
