import 'package:flutter/material.dart';
import '../services/tv_cast_service.dart';

class TvCastModal {
  static void show(BuildContext context, String videoId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TvCastDiscoverySheet(videoId: videoId),
    );
  }
}

class _TvCastDiscoverySheet extends StatefulWidget {
  final String videoId;

  const _TvCastDiscoverySheet({required this.videoId});

  @override
  State<_TvCastDiscoverySheet> createState() => _TvCastDiscoverySheetState();
}

class _TvCastDiscoverySheetState extends State<_TvCastDiscoverySheet> {
  final TvCastService _castService = TvCastService();
  final List<DiscoveredTv> _devices = [];
  bool _isScanning = true;
  String? _castingToIp;
  String? _statusMessage;
  String? _successfulIp;
  final TextEditingController _ipController = TextEditingController();
  bool _showManualInput = false;
  bool _isCheckingManualIp = false;

  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  @override
  void dispose() {
    _castService.dispose();
    _ipController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isScanning = true;
      _statusMessage = null;
      _successfulIp = null;
      _devices.clear();
    });

    _castService.startDiscovery(
      onDeviceFound: (device) {
        if (!mounted) return;
        setState(() {
          if (!_devices.any((d) => d.ip == device.ip)) {
            _devices.add(device);
          }
        });
      },
      onScanComplete: () {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
        });
      },
    );
  }

  Future<void> _castTo(DiscoveredTv tv) async {
    setState(() {
      _castingToIp = tv.ip;
      _statusMessage = 'Enviando petición DIAL a ${tv.name} (${tv.ip})...';
    });

    final success = await TvCastService.launchYouTubeOnTv(
      tv.ip,
      widget.videoId,
      customAppUrl: tv.dialAppUrl,
    );

    if (!mounted) return;

    if (success) {
      TvCastService.addSavedDevice(tv);
      setState(() {
        _castingToIp = null;
        _successfulIp = tv.ip;
        _statusMessage = '¡Vídeo enviado a la TV! Reproduciéndose en ${tv.name} 🎉';
      });
    } else {
      setState(() {
        _castingToIp = null;
        _statusMessage = 'Petición enviada a ${tv.ip}. Si la TV te pide confirmar en pantalla, pulsa Aceptar con el mando.';
      });
    }
  }

  Future<void> _addManualTv() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    setState(() {
      _isCheckingManualIp = true;
      _statusMessage = 'Comprobando conexión con $ip...';
    });

    final tv = await TvCastService.checkIp(ip);
    if (!mounted) return;

    setState(() {
      _isCheckingManualIp = false;
    });

    if (tv != null) {
      TvCastService.addSavedDevice(tv);
      setState(() {
        if (!_devices.any((d) => d.ip == tv.ip)) {
          _devices.insert(0, tv);
        }
        _showManualInput = false;
      });
      await _castTo(tv);
    } else {
      setState(() {
        _statusMessage = 'No se pudo conectar con la IP $ip. Asegúrate de que el televisor esté encendido y en la misma Wi-Fi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141F33),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF2E3F6A), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera con título y botón de cierre
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF24355A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.tv,
                          color: Color(0xFFE8EEF8),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Transmitir a la TV (DIAL)',
                            style: TextStyle(
                              color: Color(0xFFE8EEF8),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Envío directo a la app de YouTube en tu Smart TV',
                            style: TextStyle(
                              color: Color(0xFF7090C0),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF7090C0)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Barra de estado de búsqueda SSDP
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC8D4E8).withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isScanning)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7090C0)),
                        ),
                      )
                    else
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF4CAF50),
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isScanning
                            ? 'Buscando televisores en tu red Wi-Fi...'
                            : (_devices.isEmpty
                                ? 'Búsqueda finalizada (0 detectadas)'
                                : '${_devices.length} televisor(es) encontrado(s)'),
                        style: const TextStyle(
                          color: Color(0xFFC8D4E8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!_isScanning)
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reintentar'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE8EEF8),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _startSearch,
                      ),
                  ],
                ),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _successfulIp != null
                        ? const Color(0xFF1B4D3E)
                        : const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _successfulIp != null
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF7090C0),
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(
                      color: Color(0xFFE8EEF8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Lista de dispositivos encontrados
              if (_devices.isNotEmpty) ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tv = _devices[index];
                    final isCastingThis = _castingToIp == tv.ip;
                    final isSuccess = _successfulIp == tv.ip;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? const Color(0xFF153327)
                            : const Color(0xFF1A2740),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSuccess
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF7090C0).withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSuccess
                                  ? const Color(0xFF2E6B4E)
                                  : const Color(0xFF24355A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isSuccess ? Icons.check : Icons.tv,
                              color: const Color(0xFFE8EEF8),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tv.name,
                                  style: const TextStyle(
                                    color: Color(0xFFE8EEF8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'IP: ${tv.ip}${tv.isManual ? ' • Manual' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFF7090C0),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSuccess
                                  ? const Color(0xFF388E3C)
                                  : const Color(0xFF24355A),
                              foregroundColor: const Color(0xFFE8EEF8),
                              side: BorderSide(
                                color: isSuccess
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF7090C0),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            onPressed: isCastingThis ? null : () => _castTo(tv),
                            child: isCastingThis
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    isSuccess ? 'Enviado' : 'Transmitir',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else if (!_isScanning) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 38,
                        color: const Color(0xFF7090C0).withOpacity(0.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No se ha localizado la TV automáticamente',
                        style: TextStyle(
                          color: Color(0xFFE8EEF8),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Si tu router bloquea el tráfico Multicast o tu TV no responde a SSDP, puedes conectarla directamente indicando su dirección IP.',
                        style: TextStyle(
                          color: Color(0xFF8A9FB8),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Botón o formulario para conectar por IP directa
              if (!_showManualInput)
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_link, size: 18),
                  label: const Text('Conectar con IP de la TV directamente'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC8D4E8),
                    side: BorderSide(color: const Color(0xFF7090C0).withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _showManualInput = true;
                    });
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2D4A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF7090C0).withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Conectar por IP del televisor',
                        style: TextStyle(
                          color: Color(0xFFE8EEF8),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'La IP se encuentra en los Ajustes de Red de tu TV (ejemplo: 192.168.1.50):',
                        style: TextStyle(color: Color(0xFF8A9FB8), fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ipController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '192.168.1.XX',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                filled: true,
                                fillColor: const Color(0xFF141F33),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: const Color(0xFF7090C0).withOpacity(0.4)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E6B4E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isCheckingManualIp ? null : _addManualTv,
                            child: _isCheckingManualIp
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Conectar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
