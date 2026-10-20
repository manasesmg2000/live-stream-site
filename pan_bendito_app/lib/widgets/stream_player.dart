import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/native_bridge.dart';

class StreamPlayer extends StatefulWidget {
  final String videoId;

  const StreamPlayer({super.key, required this.videoId});

  @override
  State<StreamPlayer> createState() => _StreamPlayerState();
}

class _StreamPlayerState extends State<StreamPlayer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initController(widget.videoId);
  }

  void _initController(String videoId) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'TvCaster',
        onMessageReceived: (JavaScriptMessage message) async {
          final targetVideoId = message.message.isNotEmpty ? message.message : widget.videoId;
          await _openInYouTube(targetVideoId);
        },
      )
      ..loadRequest(
        Uri.parse('https://manasesmg2000.github.io/live-stream-site/embed.html?v=$videoId'),
      );
  }

  @override
  void didUpdateWidget(covariant StreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadRequest(
        Uri.parse('https://manasesmg2000.github.io/live-stream-site/embed.html?v=${widget.videoId}'),
      );
    }
  }

  Future<void> _openInYouTube([String? customId]) async {
    final vid = customId ?? widget.videoId;
    final success = await NativeBridge.openYouTube(vid);
    if (!success) {
      final uri = Uri.parse('https://www.youtube.com/watch?v=$vid');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contenedor 16:9 con sombra y bordes redondeados
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Botones de acción debajo del reproductor
        Row(
          children: [
            // Botón principal: Transmitir / Abrir en YouTube
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_filled, color: Colors.red, size: 22),
                label: const Text(
                  'Transmitir / Abrir en YouTube',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF24355A),
                  foregroundColor: const Color(0xFFE8EEF8),
                  side: const BorderSide(color: Color(0xFF7090C0), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  elevation: 3,
                ),
                onPressed: () => _openInYouTube(),
              ),
            ),
            const SizedBox(width: 8),

            // Botón Recargar reproductor
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF7090C0)),
              tooltip: 'Recargar reproductor',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _controller.loadRequest(
                  Uri.parse('https://manasesmg2000.github.io/live-stream-site/embed.html?v=${widget.videoId}'),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
