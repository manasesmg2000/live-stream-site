class CalendarEvent {
  final String id;
  final String date; // YYYY-MM-DD
  final String time; // HH:mm
  final String type; // 'culto', 'culto_especial', 'reunion'
  final String title;
  final String description;
  final bool isLiveStream;
  final String imageUrl;

  CalendarEvent({
    required this.id,
    required this.date,
    required this.time,
    required this.type,
    required this.title,
    required this.description,
    required this.isLiveStream,
    required this.imageUrl,
  });

  bool get isSpecial => type == 'culto_especial';
  bool get isReunion => type == 'reunion';

  DateTime? get parsedDate {
    try {
      final parts = date.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      type: json['type']?.toString() ?? 'culto',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isLiveStream: json['isLiveStream'] == true,
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}
