class StoryModel {
  final String userId;
  final String authorName;
  final String authorAvatar;
  final bool seen;
  final List<StorySlideModel> slides;

  StoryModel({
    required this.userId,
    required this.authorName,
    required this.authorAvatar,
    this.seen = false,
    required this.slides,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final authorJson = json['user'] as Map<String, dynamic>?;
    final slidesJson = json['slides'] as List<dynamic>? ?? [];
    
    return StoryModel(
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      authorName: authorJson != null ? (authorJson['name'] as String? ?? 'User') : json['authorName'] as String? ?? 'User',
      authorAvatar: authorJson != null ? (authorJson['avatar'] as String? ?? authorJson['image'] as String? ?? '') : json['authorAvatar'] as String? ?? '',
      seen: json['seen'] as bool? ?? false,
      slides: slidesJson.map((e) => StorySlideModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'seen': seen,
      'slides': slides.map((e) => e.toJson()).toList(),
    };
  }
}

class StorySlideModel {
  final String id;
  final String storyId;
  final String type; // 'text', 'image', 'video'
  final String? text;
  final String? emoji;
  final String? caption;
  final String gradient;
  final String? mediaUrl;
  final String timestamp;
  final String createdAt;

  StorySlideModel({
    required this.id,
    required this.storyId,
    required this.type,
    this.text,
    this.emoji,
    this.caption,
    required this.gradient,
    this.mediaUrl,
    required this.timestamp,
    required this.createdAt,
  });

  factory StorySlideModel.fromJson(Map<String, dynamic> json) {
    return StorySlideModel(
      id: json['id'] as String? ?? '',
      storyId: json['storyId'] as String? ?? json['story_id'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      emoji: json['emoji'] as String?,
      caption: json['caption'] as String?,
      gradient: json['gradient'] as String? ?? 'linear-gradient(135deg, #FF512F, #DD2476)',
      mediaUrl: json['mediaUrl'] as String? ?? json['media_url'] as String?,
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      createdAt: json['created_at'] as String? ?? json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storyId': storyId,
      'type': type,
      'text': text,
      'emoji': emoji,
      'caption': caption,
      'gradient': gradient,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp,
      'createdAt': createdAt,
    };
  }
}
