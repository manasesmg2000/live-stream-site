import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/native_bridge.dart';

class PetitionItem {
  final String id;
  final String author;
  final bool isAnonymous;
  final String text;
  final String date;
  int likes;

  PetitionItem({
    required this.id,
    required this.author,
    required this.isAnonymous,
    required this.text,
    required this.date,
    required this.likes,
  });

  factory PetitionItem.fromJson(Map<String, dynamic> json) {
    return PetitionItem(
      id: json['id']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Hermano de la Iglesia',
      isAnonymous: json['isAnonymous'] == true,
      text: json['text']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      likes: int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
    );
  }
}

class PetitionsScreen extends StatefulWidget {
  final String? initialUserName;

  const PetitionsScreen({super.key, this.initialUserName});

  @override
  State<PetitionsScreen> createState() => _PetitionsScreenState();
}

class _PetitionsScreenState extends State<PetitionsScreen> {
  static const String _peticionesApiUrl =
      'https://api.github.com/repos/manasesmg2000/live-stream-site/contents/peticiones.json?ref=main';
  static const String _peticionesJsonUrl =
      'https://raw.githubusercontent.com/manasesmg2000/live-stream-site/main/peticiones.json';
  static const String _peticionesFallbackUrl =
      'https://manasesmg2000.github.io/live-stream-site/peticiones.json';

  // Servidores de mensajería (Primario adminforge.de + Respaldo ntfy.sh)
  static const String _adminTopicPrimary =
      'https://ntfy.adminforge.de/iglesia-pan-bendito-peticiones-admin-v1';
  static const String _adminTopicFallback =
      'https://ntfy.sh/iglesia-pan-bendito-peticiones-admin-v1';

  static const String _feedTopicPrimary =
      'https://ntfy.adminforge.de/iglesia-pan-bendito-peticiones-feed-v1';
  static const String _feedTopicFallback =
      'https://ntfy.sh/iglesia-pan-bendito-peticiones-feed-v1';

  static const String _likesTopicPrimary =
      'https://ntfy.adminforge.de/iglesia-pan-bendito-peticiones-likes-v1';
  static const String _likesTopicFallback =
      'https://ntfy.sh/iglesia-pan-bendito-peticiones-likes-v1';

  List<PetitionItem> _petitions = [];
  final List<Map<String, dynamic>> _myPendingPetitions = [];
  final Set<String> _likedIds = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _authorName = 'Hermano';
  Timer? _feedTimer;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchPetitions();
    _startFeedListener();
  }

  @override
  void didUpdateWidget(covariant PetitionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUserName != null && widget.initialUserName!.trim().isNotEmpty) {
      if (_authorName == 'Hermano' || _authorName.isEmpty) {
        setState(() {
          _authorName = widget.initialUserName!.trim();
        });
      }
    }
  }

  @override
  void dispose() {
    _feedTimer?.cancel();
    super.dispose();
  }

  void _startFeedListener() {
    _feedTimer?.cancel();
    _feedTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollFeedUpdates();
    });
  }

  Future<void> _pollFeedUpdates() async {
    try {
      // 1. Escuchar actualizaciones de peticiones aprobadas / eliminadas
      final uri = Uri.parse('$_feedTopicPrimary/json?poll=1&since=12s');
      var res = await http.get(uri).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 500));
      if (res.statusCode != 200) {
        res = await http.get(Uri.parse('$_feedTopicFallback/json?poll=1&since=12s')).timeout(const Duration(seconds: 2)).catchError((_) => http.Response('', 500));
      }

      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final lines = res.body.trim().split('\n');
        bool needsRefresh = false;
        for (final line in lines) {
          if (line.isEmpty) continue;
          try {
            final obj = jsonDecode(line);
            if (obj['event'] == 'message' && obj['message'] != null) {
              final rawMsg = obj['message'].toString();
              if (rawMsg == 'UPDATE') {
                needsRefresh = true;
              } else {
                final parsed = jsonDecode(rawMsg);
                if (parsed is Map<String, dynamic>) {
                  final action = parsed['action'] ?? parsed['type'];
                  if (action == 'APPROVED' || action == 'DELETED' || action == 'REJECTED' || action == 'FEED_UPDATE') {
                    if (parsed['petitions'] is List) {
                      final list = (parsed['petitions'] as List)
                          .map((e) => PetitionItem.fromJson(e as Map<String, dynamic>))
                          .toList();
                      if (mounted) {
                        setState(() {
                          _petitions = list;
                          _myPendingPetitions.removeWhere((pending) =>
                              _petitions.any((p) => p.id == pending['id'] || (p.text == pending['text'] && p.date == pending['date'])));
                        });
                      }
                      return;
                    }
                    needsRefresh = true;
                  }
                }
              }
            }
          } catch (_) {}
        }
        if (needsRefresh && mounted) {
          _fetchPetitions();
        }
      }

      // 2. Escuchar señales de likes en tiempo real
      final likesUri = Uri.parse('$_likesTopicPrimary/json?poll=1&since=8s');
      var likesRes = await http.get(likesUri).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 500));
      if (likesRes.statusCode != 200) {
        likesRes = await http.get(Uri.parse('$_likesTopicFallback/json?poll=1&since=8s')).timeout(const Duration(seconds: 2)).catchError((_) => http.Response('', 500));
      }

      if (likesRes.statusCode == 200 && likesRes.body.trim().isNotEmpty) {
        final lines = likesRes.body.trim().split('\n');
        bool updated = false;
        for (final line in lines) {
          if (line.isEmpty) continue;
          try {
            final obj = jsonDecode(line);
            if (obj['event'] == 'message' && obj['message'] != null) {
              final msg = obj['message'].toString();
              if (msg.startsWith('LIKE:')) {
                final pid = msg.substring(5).trim();
                final idx = _petitions.indexWhere((p) => p.id == pid);
                if (idx != -1) {
                  _petitions[idx].likes += 1;
                  updated = true;
                }
              } else if (msg.startsWith('UNLIKE:')) {
                final pid = msg.substring(7).trim();
                final idx = _petitions.indexWhere((p) => p.id == pid);
                if (idx != -1) {
                  _petitions[idx].likes = (_petitions[idx].likes - 1).clamp(0, 999999);
                  updated = true;
                }
              }
            }
          } catch (_) {}
        }
        if (updated && mounted) {
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    final name = await NativeBridge.getUserName();
    final savedLikes = await NativeBridge.getLikedPetitions();
    if (mounted) {
      setState(() {
        if (name != null && name.trim().isNotEmpty) {
          _authorName = name.trim();
        } else if (widget.initialUserName != null && widget.initialUserName!.trim().isNotEmpty) {
          _authorName = widget.initialUserName!.trim();
        }
        _likedIds.addAll(savedLikes);
      });
    }
  }

  Future<void> _fetchPetitions() async {
    setState(() {
      _isLoading = _petitions.isEmpty;
      _errorMessage = null;
    });

    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      List<dynamic>? loadedList;

      // 1. Probar GitHub Contents API (0 caché, directo de Git)
      try {
        final ghUri = Uri.parse('$_peticionesApiUrl&_t=$cacheBuster');
        final ghRes = await http.get(ghUri, headers: {
          'Accept': 'application/vnd.github.v3+json',
        }).timeout(const Duration(seconds: 4));

        if (ghRes.statusCode == 200) {
          final data = jsonDecode(ghRes.body);
          if (data is Map<String, dynamic> && data['content'] != null) {
            final rawB64 = (data['content'] as String).replaceAll('\n', '').replaceAll(' ', '');
            final decodedStr = utf8.decode(base64Decode(rawB64));
            final parsed = jsonDecode(decodedStr);
            if (parsed is List) {
              loadedList = parsed;
            }
          }
        }
      } catch (_) {}

      // 2. Si falló la API, probar raw.githubusercontent.com
      if (loadedList == null) {
        try {
          final rawUri = Uri.parse('$_peticionesJsonUrl?_t=$cacheBuster');
          final rawRes = await http.get(rawUri).timeout(const Duration(seconds: 5));
          if (rawRes.statusCode == 200) {
            final parsed = jsonDecode(utf8.decode(rawRes.bodyBytes));
            if (parsed is List) loadedList = parsed;
          }
        } catch (_) {}
      }

      // 3. Fallback GitHub Pages
      if (loadedList == null) {
        final fbUri = Uri.parse('$_peticionesFallbackUrl?_t=$cacheBuster');
        final fbRes = await http.get(fbUri).timeout(const Duration(seconds: 5));
        if (fbRes.statusCode == 200) {
          final parsed = jsonDecode(utf8.decode(fbRes.bodyBytes));
          if (parsed is List) loadedList = parsed;
        }
      }

      if (loadedList != null) {
        final list = loadedList.map((e) => PetitionItem.fromJson(e as Map<String, dynamic>)).toList();

        // 4. Agregar recuento de likes acumulados desde ntfy
        try {
          var likesRes = await http
              .get(Uri.parse('$_likesTopicPrimary/json?poll=1&since=all'))
              .timeout(const Duration(seconds: 4))
              .catchError((_) => http.Response('', 500));
          if (likesRes.statusCode != 200) {
            likesRes = await http
                .get(Uri.parse('$_likesTopicFallback/json?poll=1&since=all'))
                .timeout(const Duration(seconds: 3))
                .catchError((_) => http.Response('', 500));
          }
          if (likesRes.statusCode == 200 && likesRes.body.trim().isNotEmpty) {
            final lines = likesRes.body.trim().split('\n');
            final Map<String, int> likesMap = {};
            for (final line in lines) {
              if (line.isEmpty) continue;
              try {
                final obj = jsonDecode(line);
                if (obj['event'] == 'message' && obj['message'] != null) {
                  final msg = obj['message'].toString();
                  if (msg.startsWith('LIKE:')) {
                    final pid = msg.substring(5).trim();
                    likesMap[pid] = (likesMap[pid] ?? 0) + 1;
                  } else if (msg.startsWith('UNLIKE:')) {
                    final pid = msg.substring(7).trim();
                    likesMap[pid] = ((likesMap[pid] ?? 0) - 1).clamp(0, 999999);
                  }
                }
              } catch (_) {}
            }
            for (final p in list) {
              final dynamicLikes = likesMap[p.id] ?? 0;
              if (dynamicLikes > p.likes) {
                p.likes = dynamicLikes;
              }
            }
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _petitions = list;
            _isLoading = false;

            // Reconciliar pendientes: quitar cualquier petición que ya esté en la lista pública
            _myPendingPetitions.removeWhere((pending) =>
                _petitions.any((p) => p.id == pending['id'] || (p.text == pending['text'] && p.date == pending['date'])));
          });
        }
        return;
      }
      throw Exception('Formato de datos no válido');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_petitions.isEmpty) {
            _errorMessage = 'No se pudieron cargar las peticiones. Comprueba tu conexión.';
          }
        });
      }
    }
  }

  void _toggleLike(PetitionItem item) async {
    final willLike = !_likedIds.contains(item.id);
    setState(() {
      if (willLike) {
        _likedIds.add(item.id);
        item.likes += 1;
      } else {
        _likedIds.remove(item.id);
        item.likes = (item.likes - 1).clamp(0, 999999);
      }
    });

    // Guardar en SharedPreferences nativo para persistir entre reinicios
    await NativeBridge.saveLikedPetition(item.id, willLike);

    // Enviar señal a ntfy (primario adminforge y respaldo ntfy.sh)
    try {
      final signal = willLike ? 'LIKE:${item.id}' : 'UNLIKE:${item.id}';
      http.post(
        Uri.parse(_likesTopicPrimary),
        body: signal,
      ).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 500));
      http.post(
        Uri.parse(_likesTopicFallback),
        body: signal,
      ).timeout(const Duration(seconds: 2)).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }

  void _sendLikeSignal(String petId) {
    try {
      http.post(
        Uri.parse(_likesTopicPrimary),
        body: 'LIKE:$petId',
      ).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 500));
      http.post(
        Uri.parse(_likesTopicFallback),
        body: 'LIKE:$petId',
      ).timeout(const Duration(seconds: 2)).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }

  Future<void> _openCreatePetitionDialog() async {
    final freshName = await NativeBridge.getUserName();
    if (freshName != null && freshName.trim().isNotEmpty) {
      _authorName = freshName.trim();
    } else if (widget.initialUserName != null && widget.initialUserName!.trim().isNotEmpty) {
      _authorName = widget.initialUserName!.trim();
    }

    if (!mounted) return;

    final textController = TextEditingController();
    final nameController = TextEditingController(
      text: (_authorName != 'Hermano' && _authorName.isNotEmpty) ? _authorName : '',
    );
    bool isAnonymous = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF141F33),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: Color(0xFF2E3F6A), width: 1.5)),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.volunteer_activism_rounded, color: Color(0xFFE0B96B), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Petición de Oración',
                            style: TextStyle(
                              color: Color(0xFFE8EEF8),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF8DA2C0)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Comparte tu motivo para que la congregación se una en oración por ti.',
                    style: TextStyle(color: Color(0xFF8DA2C0), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // Cuadro de texto
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Escribe aquí tu petición o necesidad...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: const Color(0xFF0D1624),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2E3F6A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0B96B), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Campo de Nombre si no es anónimo
                  if (!isAnonymous) ...[
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Tu Nombre y Apellidos o Apodo',
                        labelStyle: const TextStyle(color: Color(0xFFE0B96B), fontSize: 13),
                        hintText: 'Escribe tu nombre para la petición',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFFE0B96B), size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0D1624),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2E3F6A)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0B96B), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Switch de Publicar como Anónimo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1624),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x30A0B9DC)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAnonymous ? Icons.visibility_off : Icons.person,
                          color: isAnonymous ? const Color(0xFFE0B96B) : const Color(0xFF7090C0),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAnonymous ? 'Publicar como Anónimo' : 'Publicar con tu nombre',
                                style: const TextStyle(
                                  color: Color(0xFFE8EEF8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isAnonymous
                                    ? 'Tu nombre no será visible para nadie en la lista pública'
                                    : 'Aparecerá con tu nombre para que sepan por quién orar',
                                style: const TextStyle(color: Color(0xFF8DA2C0), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isAnonymous,
                          activeColor: const Color(0xFFE0B96B),
                          onChanged: (val) {
                            setModalState(() {
                              isAnonymous = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Aviso de Aprobación del Administrador
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x207090C0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x407090C0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.security_rounded, color: Color(0xFF7090C0), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Por orden y edificación, las peticiones deben ser aprobadas por el pastor o administrador antes de publicarse en la lista pública.',
                            style: TextStyle(color: Color(0xFFC8D4E8), fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón Enviar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0B96B),
                        foregroundColor: const Color(0xFF0D1624),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _submitPetition(
                        ctx,
                        textController.text.trim(),
                        nameController.text.trim(),
                        isAnonymous,
                      ),
                      child: const Text(
                        'Enviar para Aprobación',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPetition(BuildContext ctx, String text, String customAuthor, bool isAnonymous) async {
    if (text.isEmpty) return;
    Navigator.pop(ctx);

    // Determinar nombre real y público
    String realName = _authorName;
    if (customAuthor.isNotEmpty) {
      realName = customAuthor;
      _authorName = customAuthor;
      await NativeBridge.saveUserName(customAuthor);
    } else if (realName.isEmpty || realName == 'Hermano') {
      final saved = await NativeBridge.getUserName();
      if (saved != null && saved.isNotEmpty) {
        realName = saved;
        _authorName = saved;
      }
    }

    final petId = 'pet_${DateTime.now().millisecondsSinceEpoch}';
    final dateStr = DateTime.now().toLocal().toString().substring(0, 16);
    final displayedAuthor = isAnonymous ? 'Anónimo' : realName;

    final pendingData = {
      'id': petId,
      'author': displayedAuthor,
      'realAuthor': realName,
      'isAnonymous': isAnonymous,
      'text': text,
      'date': dateStr,
      'likes': 0,
      'status': 'pending',
    };

    setState(() {
      _myPendingPetitions.insert(0, pendingData);
    });

    // Enviar al canal del administrador (primario adminforge y respaldo ntfy.sh)
    try {
      final jsonMsg = jsonEncode(pendingData);
      await http.post(
        Uri.parse(_adminTopicPrimary),
        headers: {
          'Title': isAnonymous
              ? 'Nueva Peticion Anonima'
              : 'Peticion de $realName',
          'Priority': 'default',
          'Tags': 'pray,hand',
        },
        body: jsonMsg,
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      final jsonMsg = jsonEncode(pendingData);
      http.post(
        Uri.parse(_adminTopicFallback),
        headers: {
          'Title': isAnonymous
              ? 'Nueva Peticion Anonima'
              : 'Peticion de $realName',
          'Priority': 'default',
          'Tags': 'pray,hand',
        },
        body: jsonMsg,
      ).timeout(const Duration(seconds: 2)).catchError((_) => http.Response('', 500));
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: const Color(0xFF141F33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF7090C0), width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF81C784), size: 28),
              SizedBox(width: 10),
              Text('Petición Enviada', style: TextStyle(color: Color(0xFFE8EEF8), fontSize: 16)),
            ],
          ),
          content: const Text(
            'Tu petición de oración ha sido enviada con éxito. Será revisada y aprobada por el pastor/administrador para que aparezca en la lista general.',
            style: TextStyle(color: Color(0xFFC8D4E8), fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E3F6A),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1624),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE0B96B),
        foregroundColor: const Color(0xFF0D1624),
        icon: const Icon(Icons.edit_note_rounded, size: 22),
        label: const Text('Pedir Oración', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openCreatePetitionDialog,
      ),
      body: RefreshIndicator(
        color: const Color(0xFFE0B96B),
        backgroundColor: const Color(0xFF141F33),
        onRefresh: _fetchPetitions,
        child: CustomScrollView(
          slivers: [
            // Cabecera informativa
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E2D4A), Color(0xFF141F33)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x40A0B9DC)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0B96B).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volunteer_activism, color: Color(0xFFE0B96B), size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Peticiones de Oración',
                              style: TextStyle(
                                color: Color(0xFFE8EEF8),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '«La oración eficaz del justo puede mucho» — Santiago 5:16',
                              style: TextStyle(color: Color(0xFF7090C0), fontSize: 11.5, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Mis peticiones pendientes de revisión (si tiene alguna recién creada)
            if (_myPendingPetitions.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: Color(0xFFE0B96B), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'TUS PETICIONES EN REVISIÓN',
                            style: TextStyle(
                              color: Color(0xFFE0B96B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._myPendingPetitions.map((p) => _buildPendingCard(p)),
                    ],
                  ),
                ),
              ),

            // Contenido de la lista pública
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE0B96B)),
                      SizedBox(height: 14),
                      Text('Cargando peticiones de la congregación...', style: TextStyle(color: Color(0xFFC8D4E8), fontSize: 13)),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null && _petitions.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC8D4E8), fontSize: 14)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF223054), foregroundColor: Colors.white),
                          onPressed: _fetchPetitions,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_petitions.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No hay peticiones publicadas aún.\n¡Sé el primero en compartir un motivo de oración!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8DA2C0), fontSize: 14, height: 1.5),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _petitions[index];
                      return _buildPetitionCard(item);
                    },
                    childCount: _petitions.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2740),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0B96B).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFB89343).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('⏳ Pendiente de Aprobación', style: TextStyle(color: Color(0xFFE0B96B), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text(p['date'] ?? '', style: const TextStyle(color: Color(0xFF7090C0), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(p['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildPetitionCard(PetitionItem item) {
    final bool isLiked = _likedIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141F33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x30A0B9DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nickname / Anónimo + Fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: item.isAnonymous ? const Color(0xFF223054) : const Color(0xFF2E3F6A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.isAnonymous ? const Color(0xFF7090C0) : const Color(0xFFE0B96B),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      item.isAnonymous ? Icons.visibility_off : Icons.person,
                      size: 16,
                      color: item.isAnonymous ? const Color(0xFF8DA2C0) : const Color(0xFFE0B96B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.author,
                        style: TextStyle(
                          color: const Color(0xFFE8EEF8),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontStyle: item.isAnonymous ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      if (item.isAnonymous)
                        const Text('Petición anónima', style: TextStyle(color: Color(0xFF7090C0), fontSize: 10)),
                    ],
                  ),
                ],
              ),
              if (item.date.isNotEmpty)
                Text(
                  item.date,
                  style: const TextStyle(color: Color(0xFF7090C0), fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Texto de la petición
          Text(
            item.text,
            style: const TextStyle(
              color: Color(0xFFF0F4FC),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Barra inferior: Botón "Me gusta / Unirse en oración"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox.shrink(),
              InkWell(
                onTap: () => _toggleLike(item),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLiked ? const Color(0xFFC0392B).withOpacity(0.18) : const Color(0xFF1E2D4A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLiked ? const Color(0xFFE74C3C) : const Color(0x30A0B9DC),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? const Color(0xFFE74C3C) : const Color(0xFF8DA2C0),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLiked ? 'Orando (${item.likes})' : 'Orar / Me gusta (${item.likes})',
                        style: TextStyle(
                          color: isLiked ? const Color(0xFFE74C3C) : const Color(0xFFC8D4E8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
