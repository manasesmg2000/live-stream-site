import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/stream_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de la barra de estado y navegación del sistema
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1624),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final streamService = StreamService()..start();

  runApp(PanBenditoApp(streamService: streamService));
}

class PanBenditoApp extends StatelessWidget {
  final StreamService streamService;

  const PanBenditoApp({super.key, required this.streamService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAN BENDITO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1624),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7090C0),
          secondary: Color(0xFFC8D4E8),
          surface: Color(0xFF141F33),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: HomeScreen(streamService: streamService),
    );
  }
}
