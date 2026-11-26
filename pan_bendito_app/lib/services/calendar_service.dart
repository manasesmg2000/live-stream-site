import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/calendar_event.dart';

class CalendarService {
  static const String _apiUrl =
      'https://api.github.com/repos/manasesmg2000/live-stream-site/contents/calendario.json?ref=main';
  static const String _rawUrl =
      'https://raw.githubusercontent.com/manasesmg2000/live-stream-site/main/calendario.json';
  static const String _pagesUrl =
      'https://manasesmg2000.github.io/live-stream-site/calendario.json';

  static Future<List<CalendarEvent>> fetchEvents() async {
    final ts = DateTime.now().millisecondsSinceEpoch;

    // 1. Intentar via GitHub API (sin caché de CDN)
    try {
      final res = await http.get(
        Uri.parse('$_apiUrl&_t=$ts'),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final contentB64 = (data['content'] as String).replaceAll('\n', '');
        final decoded = utf8.decode(base64Decode(contentB64));
        return _parseEvents(decoded);
      }
    } catch (_) {}

    // 2. Fallback a raw.githubusercontent.com
    try {
      final res = await http
          .get(Uri.parse('$_rawUrl?_t=$ts'))
          .timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        return _parseEvents(utf8.decode(res.bodyBytes));
      }
    } catch (_) {}

    // 3. Fallback a GitHub Pages
    try {
      final res = await http
          .get(Uri.parse('$_pagesUrl?_t=$ts'))
          .timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        return _parseEvents(utf8.decode(res.bodyBytes));
      }
    } catch (_) {}

    return [];
  }

  static List<CalendarEvent> _parseEvents(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    final rawList = (decoded is Map && decoded['events'] is List)
        ? decoded['events'] as List
        : <dynamic>[];
    final events = rawList
        .whereType<Map<String, dynamic>>()
        .map(CalendarEvent.fromJson)
        .toList();

    events.sort((a, b) {
      final ka = '${a.date} ${a.time}';
      final kb = '${b.date} ${b.time}';
      return ka.compareTo(kb);
    });
    return events;
  }
}
