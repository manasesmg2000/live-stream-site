class StreamState {
  final bool isLive;
  final String videoId;
  final String lastVideoId;

  const StreamState({
    required this.isLive,
    required this.videoId,
    this.lastVideoId = '',
  });

  factory StreamState.fromJson(Map<String, dynamic> json) {
    return StreamState(
      isLive: json['live'] == true,
      videoId: (json['videoId'] ?? '').toString().trim(),
      lastVideoId: (json['lastVideoId'] ?? '').toString().trim(),
    );
  }

  factory StreamState.offline({String lastVideoId = ''}) {
    return StreamState(isLive: false, videoId: '', lastVideoId: lastVideoId);
  }
}
