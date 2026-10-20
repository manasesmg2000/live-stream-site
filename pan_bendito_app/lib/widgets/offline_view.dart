import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/native_bridge.dart';

class OfflineView extends StatelessWidget {
  final String lastVideoId;
  final VoidCallback? onWatchPrevious;

  const OfflineView({
    super.key,
    this.lastVideoId = '',
    this.onWatchPrevious,
  });

  Future<void> _openChannel() async {
    final uri = Uri.parse('https://www.youtube.com/@pambenditoTV');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPreviousVideo() async {
    if (onWatchPrevious != null) {
      onWatchPrevious!();
      return;
    }
    if (lastVideoId.isNotEmpty) {
      final success = await NativeBridge.openYouTube(lastVideoId);
      if (!success) {
        final uri = Uri.parse('https://www.youtube.com/watch?v=$lastVideoId');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      _openChannel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo circular con resplandor
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFC8D4E8).withOpacity(0.35),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3C5A8C).withOpacity(0.4),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/logo.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Línea divisoria suave
            Container(
              width: 50,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF7090C0).withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            const Text(
              'No hay directo disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFC8D4E8),
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Descripción
            const Text(
              'Cuando empiece la transmisión en vivo, aparecerá aquí automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7090C0),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Botón VER CULTO ANTERIOR (si hay vídeo anterior disponible)
            if (lastVideoId.isNotEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.history_rounded, color: Color(0xFFE8EEF8), size: 22),
                label: const Text(
                  'Ver culto anterior',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: const Color(0xFFE8EEF8),
                  side: const BorderSide(color: Color(0xFF7090C0), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 5,
                ),
                onPressed: _openPreviousVideo,
              ),
              const SizedBox(height: 14),
            ],

            // Botón canal de YouTube
            OutlinedButton.icon(
              icon: const Icon(Icons.play_circle_fill, color: Colors.red, size: 20),
              label: const Text('Visitar nuestro canal de YouTube'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC8D4E8),
                side: BorderSide(
                  color: const Color(0xFFC8D4E8).withOpacity(0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _openChannel,
            ),
          ],
        ),
      ),
    );
  }
}
