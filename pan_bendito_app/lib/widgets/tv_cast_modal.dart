import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TvCastModal {
  static void show(BuildContext context, String videoId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TvCastModalContent(videoId: videoId),
    );
  }
}

class _TvCastModalContent extends StatelessWidget {
  final String videoId;

  const _TvCastModalContent({required this.videoId});

  Future<void> _launchYouTubeApp(BuildContext context) async {
    final nativeUri = Uri.parse('vnd.youtube:$videoId');
    final webUri = Uri.parse('https://www.youtube.com/watch?v=$videoId');

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchTvPair(BuildContext context) async {
    final pairUri = Uri.parse('https://www.youtube.com/pair');
    await launchUrl(pairUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141F33),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF2E3F6A), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.tv, color: Color(0xFFC8D4E8), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Transmitir a la televisión',
                      style: TextStyle(
                        color: Color(0xFFE8EEF8),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
            _buildOptionCard(
              icon: Icons.cast_connected,
              title: '🔥 Amazon Firestick / Chromecast / AirPlay',
              description:
                  'Abre el directo en la app de YouTube de tu móvil. El icono de transmitir detectará automáticamente tu TV en la misma red Wi-Fi.',
              buttonLabel: '▶ Abrir para emitir a la TV',
              isPrimary: true,
              onTap: () {
                Navigator.pop(context);
                _launchYouTubeApp(context);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              icon: Icons.dialpad,
              title: '🔢 Vincular Smart TV con Código',
              description:
                  'En tu Smart TV entra en YouTube > Ajustes > Vincular con código y conéctalo aquí una sola vez.',
              buttonLabel: 'Introducir código en youtube.com/pair',
              isPrimary: false,
              onTap: () {
                Navigator.pop(context);
                _launchTvPair(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFC8D4E8).withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC8D4E8), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE8EEF8),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF7090C0),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPrimary
                  ? const Color(0xFF24355A)
                  : const Color(0xFF1A2740),
              foregroundColor: const Color(0xFFE8EEF8),
              side: BorderSide(
                color: isPrimary
                    ? const Color(0xFF7090C0)
                    : const Color(0xFF2E3F6A),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: onTap,
            child: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
