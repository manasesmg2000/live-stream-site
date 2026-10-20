import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OfflineView extends StatelessWidget {
  const OfflineView({super.key});

  Future<void> _openChannel() async {
    final uri = Uri.parse('https://www.youtube.com/@pambenditoTV');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo circular con resplandor
            Container(
              width: 140,
              height: 140,
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
                  'assets/images/logo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.church,
                    size: 64,
                    color: Color(0xFFC8D4E8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Línea divisoria suave
            Container(
              width: 60,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF7090C0).withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Título
            const Text(
              'No hay directo disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFC8D4E8),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Descripción
            const Text(
              'Vuelve pronto. Cuando empiece la transmisión en vivo, aparecerá aquí automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7090C0),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),

            // Botón canal
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_fill, color: Colors.red, size: 22),
              label: const Text('Visitar nuestro canal de YouTube'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF223054),
                foregroundColor: const Color(0xFFE8EEF8),
                side: BorderSide(
                  color: const Color(0xFFC8D4E8).withOpacity(0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                elevation: 4,
              ),
              onPressed: _openChannel,
            ),
          ],
        ),
      ),
    );
  }
}
