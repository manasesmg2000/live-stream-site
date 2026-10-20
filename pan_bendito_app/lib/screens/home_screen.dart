import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stream_state.dart';
import '../services/stream_service.dart';
import '../widgets/stream_player.dart';
import '../widgets/offline_view.dart';

class HomeScreen extends StatefulWidget {
  final StreamService streamService;

  const HomeScreen({super.key, required this.streamService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _openChannel() async {
    final uri = Uri.parse('https://www.youtube.com/@pambenditoTV');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1624),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1624), Color(0xFF223054), Color(0xFF0D1624)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border(
              bottom: BorderSide(color: Color(0x3FA0B9DC), width: 1),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo + Nombre
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x66C8D4E8),
                            width: 2,
                          ),
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
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'PAN BENDITO',
                            style: TextStyle(
                              color: Color(0xFFE8EEF8),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            'IGLESIA EVANGÉLICA',
                            style: TextStyle(
                              color: Color(0xFF7090C0),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Lado derecho: Badge Directo + Botón Canal
                  StreamBuilder<StreamState>(
                    stream: widget.streamService.stateStream,
                    initialData: widget.streamService.currentState,
                    builder: (context, snapshot) {
                      final isLive = snapshot.data?.isLive ?? false;
                      return Row(
                        children: [
                          if (isLive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC0392B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '● EN DIRECTO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: const Icon(Icons.video_library_rounded,
                                color: Color(0xFFE8EEF8), size: 22),
                            tooltip: 'Canal de YouTube',
                            onPressed: _openChannel,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF7090C0),
        backgroundColor: const Color(0xFF141F33),
        onRefresh: () => widget.streamService.fetchState(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1624), Color(0xFF1A2740), Color(0xFF0D1624)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: StreamBuilder<StreamState>(
            stream: widget.streamService.stateStream,
            initialData: widget.streamService.currentState,
            builder: (context, snapshot) {
              final state = snapshot.data ?? StreamState.offline();

              return Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: state.isLive && state.videoId.isNotEmpty
                            ? StreamPlayer(videoId: state.videoId)
                            : const OfflineView(),
                      ),
                    ),
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '© Iglesia de Pan Bendito · Iglesia Evangélica',
                      style: TextStyle(
                        color: const Color(0xFFA0B9DC).withOpacity(0.35),
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
