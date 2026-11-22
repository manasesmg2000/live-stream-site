import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BibleBook {
  final String code;
  final String name;
  final int chapters;
  final String testament; // "AT" or "NT"

  const BibleBook({
    required this.code,
    required this.name,
    required this.chapters,
    required this.testament,
  });
}

const List<BibleBook> kBibleBooks = [
  // Antiguo Testamento
  BibleBook(code: 'GEN', name: 'Génesis', chapters: 50, testament: 'AT'),
  BibleBook(code: 'EXO', name: 'Éxodo', chapters: 40, testament: 'AT'),
  BibleBook(code: 'LEV', name: 'Levítico', chapters: 27, testament: 'AT'),
  BibleBook(code: 'NUM', name: 'Números', chapters: 36, testament: 'AT'),
  BibleBook(code: 'DEU', name: 'Deuteronomio', chapters: 34, testament: 'AT'),
  BibleBook(code: 'JOS', name: 'Josué', chapters: 24, testament: 'AT'),
  BibleBook(code: 'JDG', name: 'Jueces', chapters: 21, testament: 'AT'),
  BibleBook(code: 'RUT', name: 'Rut', chapters: 4, testament: 'AT'),
  BibleBook(code: '1SA', name: '1 Samuel', chapters: 31, testament: 'AT'),
  BibleBook(code: '2SA', name: '2 Samuel', chapters: 24, testament: 'AT'),
  BibleBook(code: '1KI', name: '1 Reyes', chapters: 22, testament: 'AT'),
  BibleBook(code: '2KI', name: '2 Reyes', chapters: 25, testament: 'AT'),
  BibleBook(code: '1CH', name: '1 Crónicas', chapters: 29, testament: 'AT'),
  BibleBook(code: '2CH', name: '2 Crónicas', chapters: 36, testament: 'AT'),
  BibleBook(code: 'EZR', name: 'Esdras', chapters: 10, testament: 'AT'),
  BibleBook(code: 'NEH', name: 'Nehemías', chapters: 13, testament: 'AT'),
  BibleBook(code: 'EST', name: 'Ester', chapters: 10, testament: 'AT'),
  BibleBook(code: 'JOB', name: 'Job', chapters: 42, testament: 'AT'),
  BibleBook(code: 'PSA', name: 'Salmos', chapters: 150, testament: 'AT'),
  BibleBook(code: 'PRO', name: 'Proverbios', chapters: 31, testament: 'AT'),
  BibleBook(code: 'ECC', name: 'Eclesiastés', chapters: 12, testament: 'AT'),
  BibleBook(code: 'SNG', name: 'Cantares', chapters: 8, testament: 'AT'),
  BibleBook(code: 'ISA', name: 'Isaías', chapters: 66, testament: 'AT'),
  BibleBook(code: 'JER', name: 'Jeremías', chapters: 52, testament: 'AT'),
  BibleBook(code: 'LAM', name: 'Lamentaciones', chapters: 5, testament: 'AT'),
  BibleBook(code: 'EZK', name: 'Ezequiel', chapters: 48, testament: 'AT'),
  BibleBook(code: 'DAN', name: 'Daniel', chapters: 12, testament: 'AT'),
  BibleBook(code: 'HOS', name: 'Oseas', chapters: 14, testament: 'AT'),
  BibleBook(code: 'JOL', name: 'Joel', chapters: 3, testament: 'AT'),
  BibleBook(code: 'AMO', name: 'Amós', chapters: 9, testament: 'AT'),
  BibleBook(code: 'OBA', name: 'Abdías', chapters: 1, testament: 'AT'),
  BibleBook(code: 'JON', name: 'Jonás', chapters: 4, testament: 'AT'),
  BibleBook(code: 'MIC', name: 'Miqueas', chapters: 7, testament: 'AT'),
  BibleBook(code: 'NAM', name: 'Nahúm', chapters: 3, testament: 'AT'),
  BibleBook(code: 'HAB', name: 'Habacuc', chapters: 3, testament: 'AT'),
  BibleBook(code: 'ZEP', name: 'Sofonías', chapters: 3, testament: 'AT'),
  BibleBook(code: 'HAG', name: 'Hageo', chapters: 2, testament: 'AT'),
  BibleBook(code: 'ZEC', name: 'Zacarías', chapters: 14, testament: 'AT'),
  BibleBook(code: 'MAL', name: 'Malaquías', chapters: 4, testament: 'AT'),
  // Nuevo Testamento
  BibleBook(code: 'MAT', name: 'Mateo', chapters: 28, testament: 'NT'),
  BibleBook(code: 'MRK', name: 'Marcos', chapters: 16, testament: 'NT'),
  BibleBook(code: 'LUK', name: 'Lucas', chapters: 24, testament: 'NT'),
  BibleBook(code: 'JHN', name: 'Juan', chapters: 21, testament: 'NT'),
  BibleBook(code: 'ACT', name: 'Hechos', chapters: 28, testament: 'NT'),
  BibleBook(code: 'ROM', name: 'Romanos', chapters: 16, testament: 'NT'),
  BibleBook(code: '1CO', name: '1 Corintios', chapters: 16, testament: 'NT'),
  BibleBook(code: '2CO', name: '2 Corintios', chapters: 13, testament: 'NT'),
  BibleBook(code: 'GAL', name: 'Gálatas', chapters: 6, testament: 'NT'),
  BibleBook(code: 'EPH', name: 'Efesios', chapters: 6, testament: 'NT'),
  BibleBook(code: 'PHP', name: 'Filipenses', chapters: 4, testament: 'NT'),
  BibleBook(code: 'COL', name: 'Colosenses', chapters: 4, testament: 'NT'),
  BibleBook(code: '1TH', name: '1 Tesalonicenses', chapters: 5, testament: 'NT'),
  BibleBook(code: '2TH', name: '2 Tesalonicenses', chapters: 3, testament: 'NT'),
  BibleBook(code: '1TI', name: '1 Timoteo', chapters: 6, testament: 'NT'),
  BibleBook(code: '2TI', name: '2 Timoteo', chapters: 4, testament: 'NT'),
  BibleBook(code: 'TIT', name: 'Tito', chapters: 3, testament: 'NT'),
  BibleBook(code: 'PHM', name: 'Filemón', chapters: 1, testament: 'NT'),
  BibleBook(code: 'HEB', name: 'Hebreos', chapters: 13, testament: 'NT'),
  BibleBook(code: 'JAS', name: 'Santiago', chapters: 5, testament: 'NT'),
  BibleBook(code: '1PE', name: '1 Pedro', chapters: 5, testament: 'NT'),
  BibleBook(code: '2PE', name: '2 Pedro', chapters: 3, testament: 'NT'),
  BibleBook(code: '1JN', name: '1 Juan', chapters: 5, testament: 'NT'),
  BibleBook(code: '2JN', name: '2 Juan', chapters: 1, testament: 'NT'),
  BibleBook(code: '3JN', name: '3 Juan', chapters: 1, testament: 'NT'),
  BibleBook(code: 'JUD', name: 'Judas', chapters: 1, testament: 'NT'),
  BibleBook(code: 'REV', name: 'Apocalipsis', chapters: 22, testament: 'NT'),
];

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

enum TranslationMode { rv1960, ntv, parallel }

class _BibleScreenState extends State<BibleScreen> {
  String _selectedBookCode = 'JHN'; // Juan por defecto
  int _selectedChapter = 3;         // Capítulo 3
  int? _selectedVerse;              // null = ver capítulo completo
  TranslationMode _mode = TranslationMode.rv1960;
  double _fontSize = 17.0;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _rvData;
  Map<String, dynamic>? _ntvData;

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};

  // Cache en memoria para navegación instantánea
  static final Map<String, Map<String, dynamic>> _cache = {};

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _getVerseKey(int v) {
    return _verseKeys.putIfAbsent(v, () => GlobalKey());
  }

  List<int> _getAvailableVerses() {
    final Set<int> verses = {};
    void extract(Map<String, dynamic>? data) {
      if (data == null) return;
      final items = (data['chapter']?['items'] as List<dynamic>?) ?? [];
      for (final it in items) {
        if (it['type'] == 'verse') {
          final nums = (it['verse_numbers'] as List<dynamic>?) ?? [];
          for (final n in nums) {
            final v = int.tryParse(n.toString());
            if (v != null && v > 0) verses.add(v);
          }
        }
      }
    }

    if (_mode == TranslationMode.parallel) {
      extract(_rvData);
      extract(_ntvData);
    } else if (_mode == TranslationMode.rv1960) {
      extract(_rvData);
    } else {
      extract(_ntvData);
    }

    final list = verses.toList()..sort();
    return list;
  }

  void _scrollToVerse(int? verse) {
    setState(() {
      _selectedVerse = verse;
    });
    if (verse == null) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToVerseKey(verse);
    });
  }

  void _scrollToVerseKey(int? verse) {
    if (verse == null) return;
    final key = _verseKeys[verse];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
  }

  void _openVersePicker() {
    final verses = _getAvailableVerses();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VersePickerModal(
        bookName: _currentBook.name,
        chapter: _selectedChapter,
        verses: verses,
        selectedVerse: _selectedVerse,
        onSelected: (v) {
          Navigator.pop(ctx);
          _scrollToVerse(v);
        },
      ),
    );
  }

  BibleBook get _currentBook =>
      kBibleBooks.firstWhere((b) => b.code == _selectedBookCode, orElse: () => kBibleBooks[0]);

  int get _currentBookIndex =>
      kBibleBooks.indexWhere((b) => b.code == _selectedBookCode);

  bool get _canGoPrev => !(_currentBookIndex == 0 && _selectedChapter == 1);

  bool get _canGoNext =>
      !(_currentBookIndex == kBibleBooks.length - 1 &&
          _selectedChapter == _currentBook.chapters);

  Future<Map<String, dynamic>?> _fetchFromNetwork(String vid, String code, int chap) async {
    final key = '$vid/$code.$chap';
    if (_cache.containsKey(key)) return _cache[key];

    final url = Uri.parse(
        'https://mrk214.github.io/snapshots-by-chapter/es___spa___spa/$vid/$code.$chap.json');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        _cache[key] = data;
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadChapter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _verseKeys.clear();
    });

    try {
      if (_mode == TranslationMode.parallel) {
        final results = await Future.wait([
          _fetchFromNetwork('RVR1960_vid_149', _selectedBookCode, _selectedChapter),
          _fetchFromNetwork('NTV_vid_127', _selectedBookCode, _selectedChapter),
        ]);
        if (results[0] != null && results[1] != null) {
          setState(() {
            _rvData = results[0];
            _ntvData = results[1];
            _isLoading = false;
          });
          _afterChapterRendered();
          return;
        }
      } else if (_mode == TranslationMode.rv1960) {
        final data = await _fetchFromNetwork(
            'RVR1960_vid_149', _selectedBookCode, _selectedChapter);
        if (data != null) {
          setState(() {
            _rvData = data;
            _isLoading = false;
          });
          _afterChapterRendered();
          return;
        }
      } else {
        final data = await _fetchFromNetwork(
            'NTV_vid_127', _selectedBookCode, _selectedChapter);
        if (data != null) {
          setState(() {
            _ntvData = data;
            _isLoading = false;
          });
          _afterChapterRendered();
          return;
        }
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar el capítulo. Comprueba tu conexión.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al conectar con el servidor.';
      });
    }
  }

  void _afterChapterRendered() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedVerse != null) {
        _scrollToVerseKey(_selectedVerse);
      }
    });
  }

  void _goPrev() {
    if (!_canGoPrev) return;
    _selectedVerse = null;
    if (_selectedChapter > 1) {
      _selectedChapter--;
    } else {
      final prevBook = kBibleBooks[_currentBookIndex - 1];
      _selectedBookCode = prevBook.code;
      _selectedChapter = prevBook.chapters;
    }
    _loadChapter();
  }

  void _goNext() {
    if (!_canGoNext) return;
    _selectedVerse = null;
    if (_selectedChapter < _currentBook.chapters) {
      _selectedChapter++;
    } else {
      final nextBook = kBibleBooks[_currentBookIndex + 1];
      _selectedBookCode = nextBook.code;
      _selectedChapter = 1;
    }
    _loadChapter();
  }

  void _copyVerse(String ref, String text) {
    Clipboard.setData(ClipboardData(text: '«$text» — $ref'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Versículo copiado: $ref'),
        backgroundColor: const Color(0xFF1E3A5F),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openBookChapterPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookChapterPickerModal(
        initialBookCode: _selectedBookCode,
        initialChapter: _selectedChapter,
        onSelected: (bookCode, chapter) {
          Navigator.pop(ctx);
          setState(() {
            _selectedBookCode = bookCode;
            _selectedChapter = chapter;
            _selectedVerse = null;
          });
          _loadChapter();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1624),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de controles de la Biblia
            _buildControlBar(),

            // Contenido de la lectura
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFE0B96B)),
                          SizedBox(height: 16),
                          Text(
                            'Cargando Sagradas Escrituras...',
                            style: TextStyle(color: Color(0xFFC8D4E8), fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off_rounded,
                                    color: Colors.redAccent, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFFC8D4E8), fontSize: 15),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF223054),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _loadChapter,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildReaderView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141F33),
        border: Border(
          bottom: BorderSide(color: Color(0x3FA0B9DC), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Fila 1: Selector de Libro/Capítulo + Selector de Versículo + Flechas
          Row(
            children: [
              // Botón Selector de Libro y Capítulo
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: _openBookChapterPicker,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2D4A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x40A0B9DC)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_book_rounded,
                                  color: Color(0xFFE0B96B), size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${_currentBook.name} $_selectedChapter',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFE8EEF8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF7090C0), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botón Selector de Versículo
              InkWell(
                onTap: _openVersePicker,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedVerse != null ? const Color(0xFF223A63) : const Color(0xFF1E2D4A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedVerse != null ? const Color(0xFFE0B96B) : const Color(0x40A0B9DC),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        color: _selectedVerse != null ? const Color(0xFFE0B96B) : const Color(0xFF8DA2C0),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedVerse == null ? 'v. Todos' : 'v. $_selectedVerse',
                        style: TextStyle(
                          color: _selectedVerse != null ? const Color(0xFFE0B96B) : const Color(0xFFE8EEF8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF7090C0), size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Botón Anterior
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 26),
                color: _canGoPrev ? const Color(0xFFE8EEF8) : Colors.white24,
                onPressed: _canGoPrev ? _goPrev : null,
                tooltip: 'Capítulo anterior',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              ),

              // Botón Siguiente
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 26),
                color: _canGoNext ? const Color(0xFFE8EEF8) : Colors.white24,
                onPressed: _canGoNext ? _goNext : null,
                tooltip: 'Capítulo siguiente',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila 2: Traducciones (RV1960 / NTV / Paralelo) + Ajuste tamaño de fuente
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Selector de traducciones
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1624),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x30A0B9DC)),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildTransPill('RV1960', TranslationMode.rv1960),
                    _buildTransPill('NTV', TranslationMode.ntv),
                    _buildTransPill('Paralelo', TranslationMode.parallel, isGold: true),
                  ],
                ),
              ),

              // Controles de tamaño de letra
              Row(
                children: [
                  IconButton(
                    icon: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC8D4E8))),
                    onPressed: () {
                      if (_fontSize > 13) setState(() => _fontSize -= 1.5);
                    },
                    tooltip: 'Reducir letra',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC8D4E8))),
                    onPressed: () {
                      if (_fontSize < 28) setState(() => _fontSize += 1.5);
                    },
                    tooltip: 'Aumentar letra',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransPill(String title, TranslationMode mode, {bool isGold = false}) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        if (_mode != mode) {
          setState(() => _mode = mode);
          _loadChapter();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isGold ? const Color(0xFFB89343) : const Color(0xFF2E3F6A))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8DA2C0),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildReaderView() {
    if (_mode == TranslationMode.parallel) {
      return _buildParallelView();
    }
    final data = _mode == TranslationMode.rv1960 ? _rvData : _ntvData;
    if (data == null) return const SizedBox.shrink();

    final items = (data['chapter']?['items'] as List<dynamic>?) ?? [];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Encabezado del capítulo
        Center(
          child: Column(
            children: [
              Text(
                '${_currentBook.name} $_selectedChapter',
                style: const TextStyle(
                  color: Color(0xFFE8EEF8),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x207090C0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x407090C0)),
                ),
                child: Text(
                  _mode == TranslationMode.rv1960
                      ? 'Reina Valera 1960'
                      : 'Nueva Traducción Viviente',
                  style: const TextStyle(
                    color: Color(0xFFC8D4E8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Versículos en bloque de lectura
        ..._renderItemsList(items, _mode == TranslationMode.rv1960 ? 'RV1960' : 'NTV'),

        const SizedBox(height: 30),
        _buildBottomNavButtons(),
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _renderItemsList(List<dynamic> items, String verName) {
    final List<Widget> widgets = [];

    for (final item in items) {
      final type = item['type'] as String? ?? '';
      if (type.startsWith('heading')) {
        final lines = (item['lines'] as List<dynamic>?)?.map((e) => e.toString()).join(' ') ?? '';
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(
              lines,
              style: TextStyle(
                color: const Color(0xFFE0B96B),
                fontSize: _fontSize * 1.08,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (type == 'verse') {
        final rawNums = (item['verse_numbers'] as List<dynamic>?) ?? [];
        final vNumbers = rawNums.map((e) => e.toString()).join('-');
        final firstVInt = rawNums.isNotEmpty ? int.tryParse(rawNums.first.toString()) : null;
        final text = (item['lines'] as List<dynamic>?)?.map((e) => e.toString()).join(' ') ?? '';
        final isSelected = firstVInt != null && _selectedVerse == firstVInt;

        widgets.add(
          Container(
            key: firstVInt != null ? _getVerseKey(firstVInt) : null,
            margin: const EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 8 : 4,
              vertical: isSelected ? 4 : 2,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0x35E0B96B) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFFE0B96B) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: InkWell(
              onTap: () => _copyVerse('${_currentBook.name} $_selectedChapter:$vNumbers ($verName)', text),
              borderRadius: BorderRadius.circular(6),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: _fontSize,
                    height: 1.7,
                    color: const Color(0xFFF0F4FC),
                    fontFamily: 'Segoe UI',
                  ),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.top,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6, left: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE0B96B) : const Color(0x207090C0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          vNumbers,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF0D1624) : const Color(0xFF7090C0),
                            fontSize: _fontSize * 0.72,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    TextSpan(
                      text: text,
                      style: TextStyle(
                        fontSize: _fontSize,
                        color: isSelected ? Colors.white : const Color(0xFFF0F4FC),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildParallelView() {
    final rvItems = (_rvData?['chapter']?['items'] as List<dynamic>?) ?? [];
    final ntvItems = (_ntvData?['chapter']?['items'] as List<dynamic>?) ?? [];

    // Agrupar versículos por número para comparativa versículo a versículo
    final Map<int, String> rvVerses = {};
    final Map<int, String> ntvVerses = {};

    void extractVerses(List<dynamic> items, Map<int, String> map) {
      for (final it in items) {
        if (it['type'] == 'verse') {
          final nums = (it['verse_numbers'] as List<dynamic>?) ?? [];
          final txt = (it['lines'] as List<dynamic>?)?.map((e) => e.toString()).join(' ') ?? '';
          for (final n in nums) {
            final vInt = int.tryParse(n.toString()) ?? 0;
            if (vInt > 0) map[vInt] = txt;
          }
        }
      }
    }

    extractVerses(rvItems, rvVerses);
    extractVerses(ntvItems, ntvVerses);

    final allVerseNumbers = {...rvVerses.keys, ...ntvVerses.keys}.toList()..sort();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                '${_currentBook.name} $_selectedChapter',
                style: const TextStyle(
                  color: Color(0xFFE8EEF8),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Vista Paralela: RV1960 y NTV',
                style: TextStyle(color: Color(0xFFE0B96B), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...allVerseNumbers.map((vNum) {
          final rvText = rvVerses[vNum] ?? '';
          final ntvText = ntvVerses[vNum] ?? '';
          final isSelected = _selectedVerse == vNum;

          return Container(
            key: _getVerseKey(vNum),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E2F4A) : const Color(0xFF141F33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFFE0B96B) : const Color(0x30A0B9DC),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera del versículo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE0B96B) : const Color(0xFF223054),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Versículo $vNum',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF0D1624) : const Color(0xFFE0B96B),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF7090C0)),
                      onPressed: () => _copyVerse(
                        '${_currentBook.name} $_selectedChapter:$vNum',
                        'RV1960: $rvText\nNTV: $ntvText',
                      ),
                      tooltip: 'Copiar ambas traducciones',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reina Valera 1960
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E3F6A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('RV1960', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rvText,
                        style: TextStyle(
                          color: const Color(0xFFF0F4FC),
                          fontSize: _fontSize,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0x20A0B9DC), height: 1),
                const SizedBox(height: 8),

                // NTV
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7D5E1A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('NTV', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ntvText,
                        style: TextStyle(
                          color: const Color(0xFFE8EEF8),
                          fontSize: _fontSize,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 20),
        _buildBottomNavButtons(),
        const SizedBox(height: 20),
      ],
    );
  }

        const SizedBox(height: 20),
        _buildBottomNavButtons(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBottomNavButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E2D4A),
            foregroundColor: const Color(0xFFE8EEF8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _canGoPrev ? _goPrev : null,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Anterior'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E2D4A),
            foregroundColor: const Color(0xFFE8EEF8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _canGoNext ? _goNext : null,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('Siguiente'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// MODAL SELECTOR DE LIBRO Y CAPÍTULO
// ─────────────────────────────────────────────────────────
class _BookChapterPickerModal extends StatefulWidget {
  final String initialBookCode;
  final int initialChapter;
  final void Function(String bookCode, int chapter) onSelected;

  const _BookChapterPickerModal({
    required this.initialBookCode,
    required this.initialChapter,
    required this.onSelected,
  });

  @override
  State<_BookChapterPickerModal> createState() => _BookChapterPickerModalState();
}

class _BookChapterPickerModalState extends State<_BookChapterPickerModal> {
  String? _selectedBookCode;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final selectedBook = _selectedBookCode != null
        ? kBibleBooks.firstWhere((b) => b.code == _selectedBookCode)
        : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF111B2B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x40A0B9DC), width: 1.5)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF172439),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0x30A0B9DC))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (selectedBook != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFE0B96B)),
                    onPressed: () => setState(() => _selectedBookCode = null),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text('${selectedBook.name}: Capítulos'),
                  )
                else
                  const Text(
                    'Selecciona un Libro',
                    style: TextStyle(
                      color: Color(0xFFE8EEF8),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF8DA2C0)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Buscador si está en lista de libros
          if (selectedBook == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar libro (ej: Juan, Mateo, Salmos)...',
                  hintStyle: const TextStyle(color: Color(0xFF8DA2C0), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF7090C0), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF0D1624),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x30A0B9DC)),
                  ),
                ),
                onChanged: (val) => setState(() => _search = val.toLowerCase().trim()),
              ),
            ),

          // Contenido: Libros o Capítulos
          Expanded(
            child: selectedBook == null
                ? _buildBooksList()
                : _buildChaptersGrid(selectedBook),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksList() {
    final filtered = kBibleBooks.where((b) {
      if (_search.isEmpty) return true;
      return b.name.toLowerCase().contains(_search) ||
          b.code.toLowerCase().contains(_search);
    }).toList();

    final ot = filtered.where((b) => b.testament == 'AT').toList();
    final nt = filtered.where((b) => b.testament == 'NT').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (ot.isNotEmpty) ...[
          const Text(
            'ANTIGUO TESTAMENTO',
            style: TextStyle(
              color: Color(0xFFE0B96B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _buildBooksGrid(ot),
          const SizedBox(height: 16),
        ],
        if (nt.isNotEmpty) ...[
          const Text(
            'NUEVO TESTAMENTO',
            style: TextStyle(
              color: Color(0xFFE0B96B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _buildBooksGrid(nt),
        ],
      ],
    );
  }

  Widget _buildBooksGrid(List<BibleBook> books) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: books.map((b) {
        final isSelected = b.code == widget.initialBookCode;
        return InkWell(
          onTap: () => setState(() => _selectedBookCode = b.code),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2E3F6A) : const Color(0xFF172439),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFFE0B96B) : const Color(0x30A0B9DC),
              ),
            ),
            child: Text(
              b.name,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFE8EEF8),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChaptersGrid(BibleBook book) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: book.chapters,
      itemBuilder: (context, index) {
        final chap = index + 1;
        final isSelected = (book.code == widget.initialBookCode &&
            chap == widget.initialChapter);

        return InkWell(
          onTap: () => widget.onSelected(book.code, chap),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE0B96B) : const Color(0xFF172439),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0x30A0B9DC),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$chap',
              style: TextStyle(
                color: isSelected ? const Color(0xFF0D1624) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// MODAL SELECTOR DE VERSÍCULOS
// ─────────────────────────────────────────────────────────
class _VersePickerModal extends StatelessWidget {
  final String bookName;
  final int chapter;
  final List<int> verses;
  final int? selectedVerse;
  final void Function(int? verse) onSelected;

  const _VersePickerModal({
    required this.bookName,
    required this.chapter,
    required this.verses,
    required this.selectedVerse,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF111B2B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x40A0B9DC), width: 1.5)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF172439),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0x30A0B9DC))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tag_rounded, color: Color(0xFFE0B96B), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$bookName $chapter: Versículos',
                      style: const TextStyle(
                        color: Color(0xFFE8EEF8),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF8DA2C0)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Botón para seleccionar capítulo completo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: InkWell(
              onTap: () => onSelected(null),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedVerse == null ? const Color(0xFFE0B96B) : const Color(0xFF1E2D4A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selectedVerse == null ? Colors.white : const Color(0x40A0B9DC),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '📖 Ver capítulo completo (Todos)',
                  style: TextStyle(
                    color: selectedVerse == null ? const Color(0xFF0D1624) : const Color(0xFFE8EEF8),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Grid de versículos
          Expanded(
            child: verses.isEmpty
                ? const Center(
                    child: Text(
                      'No hay versículos disponibles',
                      style: TextStyle(color: Color(0xFF8DA2C0)),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: verses.length,
                    itemBuilder: (context, index) {
                      final vNum = verses[index];
                      final isSelected = selectedVerse == vNum;

                      return InkWell(
                        onTap: () => onSelected(vNum),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE0B96B) : const Color(0xFF172439),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.white : const Color(0x30A0B9DC),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$vNum',
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF0D1624) : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
