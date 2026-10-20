import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tv_cast_modal.dart';

class StreamPlayer extends StatefulWidget {
  final String videoId;

  const StreamPlayer({super.key, required this.videoId});

  @override
  State<StreamPlayer> createState() => _StreamPlayerState();
}

class _StreamPlayerState extends State<StreamPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _initController(widget.videoId);
  }

  void _initController(String id) {
    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        isLive: true,
        enableCaption: false,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant StreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.load(widget.videoId);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        // Contenedor del reproductor de vídeo
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFFC0392B),
              progressColors: const ProgressBarColors(
                playedColor: Color(0xFFC0392B),
                handleColor: Color(0xFFE74C3C),
              ),
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
