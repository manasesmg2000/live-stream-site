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
  static const String _peticionesJsonUrl =
      'https://raw.githubusercontent.com/manasesmg2000/live-stream-site/main/peticiones.json';
  static const String _peticionesFallbackUrl =
      'https://manasesmg2000.github.io/live-stream-site/peticiones.json';
  static const String _adminTopic =
      'https://ntfy.sh/iglesia-pan-bendito-peticiones-admin-v1';
  static const String _likesTopic =
      'https://ntfy.sh/iglesia-pan-bendito-peticiones-likes-v1';

  List<PetitionItem> _petitions = [];
  final List<Map<String, dynamic>> _myPendingPetitions = [];
  final Set<String> _likedIds = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _authorName = 'Hermano';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchPetitions();
  }

  Future<void> _loadUser() async {
    final name = await NativeBridge.getUserName();
    if (name != null && name.trim().isNotEmpty) {
      setState(() {
        _authorName = name.trim();
      });
    } else if (widget.initialUserName != null && widget.initialUserName!.isNotEmpty) {
      setState(() {
        _authorName = widget.initialUserName!;
      });
    }
  }

  Future<void> _fetchPetitions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$_peticionesJsonUrl?_t=$cacheBuster');
      var res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        // Fallback
        res = await http.get(Uri.parse('$_peticionesFallbackUrl?_t=$cacheBuster'))
            .timeout(const Duration(seconds: 8));
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is List) {
          final list = decoded.map((e) => PetitionItem.fromJson(e as Map<String, dynamic>)).toList();
          setState(() {
            _petitions = list;
            _isLoading = false;
          });
          return;
        }
      }
      throw Exception('Formato de datos no válido');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudieron cargar las peticiones. Comprueba tu conexión.';
      });
    }
  }

  void _toggleLike(PetitionItem item) {
    setState(() {
      if (_likedIds.contains(item.id)) {
        _likedIds.remove(item.id);
        item.likes = (item.likes - 1).clamp(0, 999999);
      } else {
        _likedIds.add(item.id);
        item.likes += 1;
        _sendLikeSignal(item.id);
      }
    });
  }

  void _sendLikeSignal(String petId) {
    try {
      http.post(
        Uri.parse(_likesTopic),
        body: 'LIKE:$petId',
      ).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 500));
    } catch (_) {}
  }

  void _openCreatePetitionDialog() {
    final textController = TextEditingController();
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
                                  ? 'Tu nombre no será visible para nadie'
                                  : 'Aparecerá como: $_authorName',
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
                    onPressed: () => _submitPetition(ctx, textController.text.trim(), isAnonymous),
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
    );
  }

  Future<void> _submitPetition(BuildContext ctx, String text, bool isAnonymous) async {
    if (text.isEmpty) return;
    Navigator.pop(ctx);

    final petId = 'pet_${DateTime.now().millisecondsSinceEpoch}';
    final dateStr = DateTime.now().toLocal().toString().substring(0, 16);
    final displayedAuthor = isAnonymous ? 'Anónimo' : _authorName;

    final pendingData = {
      'id': petId,
      'author': displayedAuthor,
      'realAuthor': _authorName,
      'isAnonymous': isAnonymous,
      'text': text,
      'date': dateStr,
      'likes': 0,
      'status': 'pending',
    };

    setState(() {
      _myPendingPetitions.insert(0, pendingData);
    });

    // Enviar al canal del administrador (ntfy)
    try {
      final jsonMsg = jsonEncode(pendingData);
      await http.post(
        Uri.parse(_adminTopic),
        headers: {
          'Title': isAnonymous
              ? 'Nueva Peticion Anonima'
              : 'Peticion de $_authorName',
          'Priority': 'default',
          'Tags': 'pray,hand',
        },
        body: jsonMsg,
      ).timeout(const Duration(seconds: 5));
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
