import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stream_state.dart';
import '../services/stream_service.dart';
import '../services/native_bridge.dart';
import '../services/presence_service.dart';
import '../widgets/stream_player.dart';
import '../widgets/offline_view.dart';
import 'bible_screen.dart';
import 'petitions_screen.dart';

class HomeScreen extends StatefulWidget {
  final StreamService streamService;

  const HomeScreen({super.key, required this.streamService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _userName;
  bool _showingPreviousVideo = false;
  int _selectedNavIndex = 0; // 0: Directo, 1: Santa Biblia, 2: Peticiones
  final List<int> _tabHistory = [0];
  DateTime? _lastBackPressTime;

  void _switchTab(int index) {
    if (_selectedNavIndex != index) {
      setState(() {
        _selectedNavIndex = index;
        _tabHistory.add(index);
      });
    }
  }

  Future<bool> _handleWillPop() async {
    // 1. Si está viendo el culto anterior, volver al reproductor principal
    if (_showingPreviousVideo) {
      setState(() {
        _showingPreviousVideo = false;
      });
      return false; // No salir
    }

    // 2. Si navegó por varias pestañas, volver a la pestaña anterior
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _selectedNavIndex = _tabHistory.last;
      });
      return false; // No salir
    }

    // 3. Si no está en Directo (pestaña 0), volver a Directo
    if (_selectedNavIndex != 0) {
      setState(() {
        _selectedNavIndex = 0;
        _tabHistory.clear();
        _tabHistory.add(0);
      });
      return false; // No salir
    }

    // 4. Si ya está en la pantalla inicial, requerir doble pulsación para salir (evita cierres accidentales)
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Presiona atrás de nuevo para salir de la app'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF1E3A5F),
        ),
      );
      return false; // No salir todavía
    }

    return true; // Permitir salida de la app
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NativeBridge.requestNotificationPermission();
    _checkUserRegistration();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.logout();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      PresenceService.logout();
    } else if (state == AppLifecycleState.resumed && _userName != null) {
      PresenceService.registerAndStart(_userName!);
    }
  }

  Future<void> _checkUserRegistration() async {
    final name = await NativeBridge.getUserName();
    if (name != null && name.trim().isNotEmpty) {
      setState(() {
        _userName = name.trim();
      });
      // Registrar entrada en el log y activar presencia en tiempo real
      PresenceService.registerAndStart(_userName!);
    } else {
      // Primera vez: mostrar diálogo de bienvenida para solicitar Nombre y Apellidos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNameDialog(isFirstTime: true);
      });
    }
  }

  void _showNameDialog({bool isFirstTime = false}) {
    final controller = TextEditingController(text: _userName ?? '');
    showDialog(
      context: context,
      barrierDismissible: !isFirstTime,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => !isFirstTime,
        child: AlertDialog(
          backgroundColor: const Color(0xFF141F33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF2E3F6A), width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF7090C0), width: 1.5),
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFirstTime ? '¡Bienvenido a la App!' : 'Tu Nombre y Apellidos',
                  style: const TextStyle(
                    color: Color(0xFFE8EEF8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFirstTime
                    ? 'Por favor, escribe tu Nombre y Apellidos para registrar tu asistencia a las transmisiones y cultos.'
                    : 'Puedes actualizar tu nombre para el registro de asistencia:',
                style: const TextStyle(
                  color: Color(0xFF8A9FB8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ej: Manuel García',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: const Color(0xFF0D1624),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF7090C0)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2E3F6A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7090C0), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF24355A),
                foregroundColor: const Color(0xFFE8EEF8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final enteredName = controller.text.trim();
                if (enteredName.isEmpty) return;

                Navigator.pop(ctx);
                await NativeBridge.saveUserName(enteredName);
                setState(() {
                  _userName = enteredName;
                });
                PresenceService.registerAndStart(enteredName);
              },
              child: const Text('Guardar y Continuar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChannel() async {
    final uri = Uri.parse('https://www.youtube.com/@pambenditoTV');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
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
                  // Logo + Nombre de la Iglesia
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
                        children: [
                          const Text(
                            'PAN BENDITO',
                            style: TextStyle(
                              color: Color(0xFFE8EEF8),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showNameDialog(isFirstTime: false),
                            child: Row(
                              children: [
                                Text(
                                  _userName != null && _userName!.isNotEmpty
                                      ? 'Hermano: $_userName'
                                      : 'IGLESIA EVANGÉLICA',
                                  style: TextStyle(
                                    color: _userName != null ? const Color(0xFF81C784) : const Color(0xFF7090C0),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                if (_userName != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 10, color: Color(0xFF81C784)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Lado derecho: Badge Directo + Botón Biblia + Botón Canal
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
                            const SizedBox(width: 6),
                          ],
                          IconButton(
                            icon: Icon(
                              Icons.menu_book_rounded,
                              color: _selectedNavIndex == 1
                                  ? const Color(0xFFE0B96B)
                                  : const Color(0xFFE8EEF8),
                              size: 22,
                            ),
                            tooltip: 'Santa Biblia (RV1960 y NTV)',
                            onPressed: () => _switchTab(1),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.volunteer_activism_rounded,
                              color: _selectedNavIndex == 2
                                  ? const Color(0xFFE0B96B)
                                  : const Color(0xFFE8EEF8),
                              size: 22,
                            ),
                            tooltip: 'Peticiones de Oración',
                            onPressed: () => _switchTab(2),
                          ),
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
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          _buildStreamTab(),
          const BibleScreen(),
          PetitionsScreen(initialUserName: _userName),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111B2B),
          border: Border(
            top: BorderSide(color: Color(0x30A0B9DC), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: _switchTab,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFE0B96B),
          unselectedItemColor: const Color(0xFF7090C0),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.live_tv_rounded),
              activeIcon: Icon(Icons.live_tv_rounded, color: Color(0xFFE0B96B)),
              label: 'Directo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              activeIcon: Icon(Icons.menu_book_rounded, color: Color(0xFFE0B96B)),
              label: 'Santa Biblia',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.volunteer_activism_rounded),
              activeIcon: Icon(Icons.volunteer_activism_rounded, color: Color(0xFFE0B96B)),
              label: 'Peticiones',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamTab() {
    return RefreshIndicator(
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

            // Si está en directo, mostramos el directo; si no, o si eligió ver el culto anterior:
            final bool showPlayer = (state.isLive && state.videoId.isNotEmpty && !_showingPreviousVideo) ||
                (_showingPreviousVideo && state.lastVideoId.isNotEmpty);

            final String currentPlayId = _showingPreviousVideo
                ? state.lastVideoId
                : state.videoId;

            return Column(
              children: [
                if (_showingPreviousVideo)
                  Container(
                    color: const Color(0xFF1E3A5F),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: Color(0xFFE8EEF8), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Viendo: Culto anterior',
                            style: TextStyle(color: Color(0xFFE8EEF8), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF90CAF9),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () {
                            setState(() {
                              _showingPreviousVideo = false;
                            });
                          },
                          child: const Text('Volver al inicio'),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: showPlayer
                          ? StreamPlayer(videoId: currentPlayId)
                          : OfflineView(
                              lastVideoId: state.lastVideoId,
                              onWatchPrevious: () {
                                if (state.lastVideoId.isNotEmpty) {
                                  setState(() {
                                    _showingPreviousVideo = true;
                                  });
                                } else {
                                  _openChannel();
                                }
                              },
                              onOpenBible: () => _switchTab(1),
                            ),
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
    );
  }
}
