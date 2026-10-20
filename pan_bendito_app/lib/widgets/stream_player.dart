import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tv_cast_modal.dart';

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

  String _buildHtml(String videoId) {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; background: #000; }
    html, body { width: 100%; height: 100%; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe
    id="yt-player"
    src="https://www.youtube.com/embed/$videoId?autoplay=1&enablejsapi=1&playsinline=1&rel=0&modestbranding=1&origin=https%3A%2F%2Fmanasesmg2000.github.io&widget_referrer=https%3A%2F%2Fmanasesmg2000.github.io"
    title="Directo en vivo"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    referrerpolicy="strict-origin-when-cross-origin"
    allowfullscreen>
  </iframe>
</body>
</html>
''';
  }

  Future<void> _openYouTube() async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            // Botón Transmitir a la TV (Búsqueda activa de dispositivos)
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.tv, size: 18),
                label: const Text('Transmitir a la TV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF24355A),
                  foregroundColor: const Color(0xFFE8EEF8),
                  side: const BorderSide(color: Color(0xFF7090C0), width: 0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
                onPressed: () => TvCastModal.show(context, widget.videoId),
              ),
            ),
            const SizedBox(width: 8),

            // Botón Abrir en YouTube
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('YouTube'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE8EEF8),
                side: BorderSide(
                  color: const Color(0xFFC8D4E8).withOpacity(0.25),
                ),
                backgroundColor: Colors.white.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
              onPressed: _openYouTube,
            ),
            const SizedBox(width: 6),

            // Botón Recargar reproductor
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF7090C0)),
              tooltip: 'Recargar vídeo',
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
