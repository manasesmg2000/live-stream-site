import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() => _isLoading = true);
    final events = await CalendarService.fetchEvents();
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  List<CalendarEvent> get _filteredEvents {
    if (_showAll) return _events;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _events.where((e) {
      final d = e.parsedDate;
      if (d == null) return true;
      return !d.isBefore(today);
    }).toList();
  }

  static const _weekDaysShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
  static const _weekDaysFull = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];
  static const _monthsShort = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
  ];
  static const _monthsFull = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  String _formatFullDate(DateTime? d, String raw) {
    if (d == null) return raw;
    final wd = _weekDaysFull[d.weekday - 1];
    final m = _monthsFull[d.month - 1];
    return '$wd ${d.day} de $m';
  }

  String? _relativeDayTag(DateTime? d) {
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'HOY';
    if (diff == 1) return 'MAÑANA';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredEvents;
    final specialPosts = visible.where((e) => e.isSpecial).toList();

    // Agrupar por fecha
    final Map<String, List<CalendarEvent>> grouped = {};
    for (final ev in visible) {
      grouped.putIfAbsent(ev.date, () => []).add(ev);
    }
    final sortedDates = grouped.keys.toList()..sort();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1624), Color(0xFF16233A), Color(0xFF0D1624)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: RefreshIndicator(
        color: const Color(0xFFE0B96B),
        backgroundColor: const Color(0xFF141F33),
        onRefresh: _loadCalendar,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE0B96B)),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  // Cabecera moderna + filtro
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0B96B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE0B96B).withOpacity(0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFFE0B96B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calendario de Cultos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'Horarios, reuniones y cultos especiales',
                              style: TextStyle(
                                color: Color(0xFF8FA5C7),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Selector Próximos / Todos
                  Row(
                    children: [
                      _filterChip('Próximos', !_showAll, () {
                        setState(() => _showAll = false);
                      }),
                      const SizedBox(width: 8),
                      _filterChip('Todos', _showAll, () {
                        setState(() => _showAll = true);
                      }),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadCalendar,
                        icon: const Icon(Icons.refresh_rounded,
                            color: Color(0xFF8FA5C7), size: 20),
                        tooltip: 'Actualizar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (visible.isEmpty)
                    _buildEmptyState()
                  else ...[
                    // Posts destacados de Cultos Especiales
                    if (specialPosts.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFFE0B96B), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'CULTOS ESPECIALES DESTACADOS',
                              style: TextStyle(
                                color: Color(0xFFE0B96B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...specialPosts.map(_buildSpecialPostCard),
                      const SizedBox(height: 12),
                    ],

                    // Agenda por día
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(Icons.event_note_rounded,
                              color: Color(0xFF8FA5C7), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'PROGRAMACIÓN POR DÍA',
                            style: TextStyle(
                              color: Color(0xFF8FA5C7),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...sortedDates.map(
                      (dateKey) => _buildDayGroupCard(dateKey, grouped[dateKey]!),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE0B96B).withOpacity(0.2)
              : const Color(0xFF141F33),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFFE0B96B) : const Color(0xFF263654),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFE0B96B) : const Color(0xFF8FA5C7),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF141F33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF263654)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 48,
            color: const Color(0xFF7090C0).withOpacity(0.7),
          ),
          const SizedBox(height: 12),
          const Text(
            'No hay eventos programados',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando se publiquen próximos cultos, reuniones o cultos especiales aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8FA5C7), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialPostCard(CalendarEvent ev) {
    final d = ev.parsedDate;
    final dateText = _formatFullDate(d, ev.date);
    final relTag = _relativeDayTag(d);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2B45), Color(0xFF131D31)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFE0B96B).withOpacity(0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0B96B).withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ev.imageUrl.isNotEmpty)
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    ev.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFF0D1624),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE0B96B),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0D1624),
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Color(0xFF7090C0), size: 36),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _specialBadge(),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _liveStatusBadge(ev.isLiveStream, solid: true),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ev.imageUrl.isEmpty) ...[
                  Row(
                    children: [
                      _specialBadge(),
                      const Spacer(),
                      _liveStatusBadge(ev.isLiveStream),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFFE0B96B), size: 15),
                    const SizedBox(width: 6),
                    Text(
                      '$dateText · ${ev.time} h',
                      style: const TextStyle(
                        color: Color(0xFFE0B96B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (relTag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0B96B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          relTag,
                          style: const TextStyle(
                            color: Color(0xFF0D1624),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ev.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (ev.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    ev.description,
                    style: const TextStyle(
                      color: Color(0xFFB8C7E0),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayGroupCard(String dateKey, List<CalendarEvent> dayEvents) {
    final d = dayEvents.first.parsedDate;
    final hasSpecial = dayEvents.any((e) => e.isSpecial);
    final relTag = _relativeDayTag(d);

    final String dayNum = d != null ? '${d.day}' : dateKey;
    final String weekDay = d != null ? _weekDaysShort[d.weekday - 1] : '';
    final String month = d != null ? _monthsShort[d.month - 1] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141F33),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasSpecial
              ? const Color(0xFFE0B96B).withOpacity(0.55)
              : const Color(0xFF263654),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna izquierda: tarjeta de fecha moderna
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: hasSpecial || relTag == 'HOY'
                  ? const Color(0xFFE0B96B).withOpacity(0.16)
                  : const Color(0xFF0D1624),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasSpecial || relTag == 'HOY'
                    ? const Color(0xFFE0B96B).withOpacity(0.6)
                    : const Color(0xFF263654),
              ),
            ),
            child: Column(
              children: [
                Text(
                  weekDay,
                  style: TextStyle(
                    color: hasSpecial || relTag == 'HOY'
                        ? const Color(0xFFE0B96B)
                        : const Color(0xFF8FA5C7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayNum,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  month,
                  style: const TextStyle(
                    color: Color(0xFF8FA5C7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (relTag != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0B96B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      relTag,
                      style: const TextStyle(
                        color: Color(0xFF0D1624),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Columna derecha: todos los horarios de ese día (cultos y reuniones)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < dayEvents.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      color: Color(0xFF263654),
                      height: 18,
                    ),
                  _buildSlotItem(dayEvents[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotItem(CalendarEvent ev) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1624),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2E4168)),
              ),
              child: Text(
                '🕐 ${ev.time} h',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _typeBadge(ev.type),
            _liveStatusBadge(ev.isLiveStream),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          ev.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (ev.description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            ev.description,
            style: const TextStyle(
              color: Color(0xFFA0B9DC),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
        if (ev.imageUrl.isNotEmpty && !ev.isSpecial) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              ev.imageUrl,
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _specialBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0B96B), Color(0xFFC89B3C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFF0D1624), size: 13),
          SizedBox(width: 4),
          Text(
            'CULTO ESPECIAL',
            style: TextStyle(
              color: Color(0xFF0D1624),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    if (type == 'culto_especial') {
      return _specialBadge();
    }
    final isReunion = type == 'reunion';
    final bg = isReunion
        ? const Color(0xFF2ECC71).withOpacity(0.16)
        : const Color(0xFF3498DB).withOpacity(0.18);
    final border = isReunion
        ? const Color(0xFF2ECC71).withOpacity(0.5)
        : const Color(0xFF3498DB).withOpacity(0.5);
    final fg = isReunion ? const Color(0xFF7EE2A8) : const Color(0xFF8ECAE6);
    final label = isReunion ? '🤝 Reunión' : '⛪ Culto';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _liveStatusBadge(bool isLive, {bool solid = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isLive
            ? (solid
                ? const Color(0xFFC0392B)
                : const Color(0xFFE74C3C).withOpacity(0.2))
            : (solid
                ? const Color(0xFF1E2B45).withOpacity(0.9)
                : const Color(0xFF7090C0).withOpacity(0.14)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive
              ? const Color(0xFFE74C3C).withOpacity(0.65)
              : const Color(0xFF7090C0).withOpacity(0.35),
        ),
      ),
      child: Text(
        isLive ? '🔴 En directo' : '⛪ Solo presencial',
        style: TextStyle(
          color: isLive
              ? (solid ? Colors.white : const Color(0xFFFF8A80))
              : const Color(0xFFB0C4DE),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
