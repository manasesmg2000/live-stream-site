import 'dart:io';
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

class _TvCastDiscoverySheetState extends State<_TvCastDiscoverySheet>
    with SingleTickerProviderStateMixin {
  final TvCastService _castService = TvCastService();
  final List<DiscoveredTv> _devices = [];
  bool _isScanning = true;
  String? _castingToId;
  String? _statusMessage;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _startSearch();
  }

  @override
  void dispose() {
    _castService.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isScanning = true;
      _statusMessage = null;
    });

    _castService.startDiscovery(
      onDeviceFound: (device) {
        if (!mounted) return;
        setState(() {
          if (!_devices.any((d) => d.id == device.id || d.ip == device.ip)) {
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
      _castingToId = tv.id;
      _statusMessage = 'Conectando con ${tv.name}...';
    });

    final success = await _castService.castToDevice(tv, widget.videoId);

    if (!mounted) return;
    setState(() {
      _castingToId = null;
      if (success) {
        _statusMessage = '¡Emitiendo en ${tv.name}! 🎉';
      } else {
        _statusMessage =
            'La TV recibió la señal. Si no abre automáticamente, asegúrate de que YouTube está instalado en la TV.';
      }
    });
  }

  Future<void> _openSystemCast() async {
    final opened = await _castService.openSystemCastSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'En iOS, desliza el Centro de Control y pulsa "Duplicar pantalla / AirPlay".',
          ),
          backgroundColor: Color(0xFF1A2740),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                          'Buscar dispositivos de TV',
                          style: TextStyle(
                            color: Color(0xFFE8EEF8),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Emisión en directo a pantalla grande',
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

            // Barra de estado de búsqueda
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF7090C0)),
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
                          ? 'Buscando Smart TVs y pantallas en tu Wi-Fi...'
                          : (_devices.isEmpty
                              ? 'Búsqueda Wi-Fi completada (0 detectadas)'
                              : '${_devices.length} pantalla(s) encontrada(s)'),
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
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF7090C0)),
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

            // Lista de dispositivos encontrados o mensaje si no hay ninguno
            Flexible(
              child: _devices.isNotEmpty
                  ? ListView.separated(
                      shrinkWrap: true,
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tv = _devices[index];
                        final isCastingThis = _castingToId == tv.id;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2740),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF7090C0).withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF24355A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.tv,
                                  color: Color(0xFFE8EEF8),
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
                                      'Wi-Fi: ${tv.ip}${tv.manufacturer != null ? ' • ${tv.manufacturer}' : ''}',
                                      style: const TextStyle(
                                        color: Color(0xFF7090C0),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF24355A),
                                  foregroundColor: const Color(0xFFE8EEF8),
                                  side: const BorderSide(
                                    color: Color(0xFF7090C0),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: isCastingThis ? null : () => _castTo(tv),
                                child: isCastingThis
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Transmitir',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_input_antenna,
                            size: 40,
                            color: const Color(0xFF7090C0).withOpacity(0.6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isScanning
                                ? 'Escaneando dispositivos Smart TV cercanos...'
                                : 'Si tu TV no aparece arriba o usas Chromecast, pulsa el botón de abajo para detectarla con el sistema:',
                            style: const TextStyle(
                              color: Color(0xFF8A9FB8),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 14),

            // Tarjeta de acceso directo al selector de Cast nativo del sistema
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFC8D4E8).withOpacity(0.18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cast_connected,
                      color: Color(0xFFC8D4E8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Chromecast / Pantalla Cast',
                          style: TextStyle(
                            color: Color(0xFFE8EEF8),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Buscar con el selector nativo del sistema',
                          style: TextStyle(
                            color: Color(0xFF7090C0),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE8EEF8),
                      side: const BorderSide(color: Color(0xFF7090C0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _openSystemCast,
                    child: const Text(
                      'Buscar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
