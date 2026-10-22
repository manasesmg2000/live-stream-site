import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1624),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AdmPbApp());
}

class AdmPbApp extends StatelessWidget {
  const AdmPbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADM PB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1624),
        primaryColor: const Color(0xFFE0B96B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141F33),
          elevation: 0,
        ),
      ),
      home: const AdminHomeScreen(),
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const String _adminUrl =
      'https://manasesmg2000.github.io/live-stream-site/admin.html';

  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;
  String _errorMessage = '';
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1624))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _hasError = false;
                _loadingProgress = 10;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            // Si es un enlace externo fuera del sitio de administración, abrirlo en el navegador
            if (!request.url.contains('manasesmg2000.github.io/live-stream-site/admin.html') &&
                !request.url.startsWith('about:') &&
                !request.url.startsWith('data:')) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('$_adminUrl?_t=${DateTime.now().millisecondsSinceEpoch}'));
  }

  Future<bool> _handleWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFE0B96B), size: 18),
                SizedBox(width: 10),
                Text('Presiona atrás de nuevo para salir de ADM PB'),
              ],
            ),
            backgroundColor: const Color(0xFF141F33),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF2E3F6A)),
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  void _reload() {
    setState(() {
      _hasError = false;
      _loadingProgress = 10;
    });
    _controller.loadRequest(
      Uri.parse('$_adminUrl?_t=${DateTime.now().millisecondsSinceEpoch}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
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
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADM PB',
                style: TextStyle(
                  color: Color(0xFFE0B96B),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Panel Oficial de Administración',
                style: TextStyle(
                  color: Color(0xFF8DA2C0),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFFE0B96B)),
              tooltip: 'Recargar Panel',
              onPressed: _reload,
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, color: Color(0xFF8DA2C0)),
              tooltip: 'Abrir en navegador',
              onPressed: () {
                launchUrl(Uri.parse(_adminUrl), mode: LaunchMode.externalApplication);
              },
            ),
          ],
          bottom: _loadingProgress < 100 && !_hasError
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    backgroundColor: const Color(0xFF141F33),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE0B96B)),
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: _hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Color(0xFFE57373), size: 54),
                      const SizedBox(height: 16),
                      const Text(
                        'No se pudo conectar con el Panel',
                        style: TextStyle(color: Color(0xFFE8EEF8), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage.isNotEmpty ? _errorMessage : 'Comprueba tu conexión a Internet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF8DA2C0), fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0B96B),
                          foregroundColor: const Color(0xFF0D1624),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _reload,
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFFE0B96B),
                backgroundColor: const Color(0xFF141F33),
                onRefresh: () async {
                  _reload();
                },
                child: WebViewWidget(controller: _controller),
              ),
      ),
    );
  }
}
