import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/tv_cast_service.dart';
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
      ..addJavaScriptChannel(
        'TvCaster',
        onMessageReceived: (JavaScriptMessage message) async {
          final targetVideoId = message.message.isNotEmpty ? message.message : widget.videoId;
          final tvIp = await TvCastService.discoverFirstTvIp();
          if (tvIp != null) {
            await TvCastService.launchYouTubeOnTv(tvIp, targetVideoId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Vídeo enviado a la TV ($tvIp)'),
                  backgroundColor: const Color(0xFF1B4D3E),
                ),
              );
            }
          } else if (mounted) {
            TvCastModal.show(context, targetVideoId);
          }
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
            // Botón Transmitir a la TV (Búsqueda DIAL activa)
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
