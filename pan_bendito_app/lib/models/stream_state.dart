class StreamState {
  final bool isLive;
  final String videoId;

  const StreamState({
    required this.isLive,
    required this.videoId,
  });

  factory StreamState.fromJson(Map<String, dynamic> json) {
    return StreamState(
      isLive: json['live'] == true,
      videoId: (json['videoId'] ?? '').toString().trim(),
    );
  }

  factory StreamState.offline() {
    return const StreamState(isLive: false, videoId: '');
  }
}
