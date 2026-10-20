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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..loadHtmlString(_buildHtml(widget.videoId));
  }

  @override
  void didUpdateWidget(covariant StreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadHtmlString(_buildHtml(widget.videoId));
    }
  }

  String _buildHtml(String videoId) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; background: #000; }
    html, body { width: 100%; height: 100%; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe
    src="https://www.youtube.com/embed/$videoId?autoplay=1&enablejsapi=1&playsinline=1"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
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
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Botón Transmitir a la TV
            ElevatedButton.icon(
              icon: const Icon(Icons.tv, size: 18),
              label: const Text('Transmitir a la TV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF24355A),
                foregroundColor: const Color(0xFFE8EEF8),
                side: const BorderSide(color: Color(0xFF7090C0), width: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => TvCastModal.show(context, widget.videoId),
            ),
            const SizedBox(width: 10),

            // Botón Abrir en YouTube
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Abrir en YouTube'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE8EEF8),
                side: BorderSide(
                  color: const Color(0xFFC8D4E8).withOpacity(0.25),
                ),
                backgroundColor: Colors.white.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: _openYouTube,
            ),
          ],
        ),
      ],
    );
  }
}
