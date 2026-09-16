import 'package:spillcity/data/database/local_db.dart';

class PostModel {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String imageUrl;
  final String? localImageUrl;
  final String? videoUrl;
  final String publishedAt;
  final int likes;
  final int comments;
  final String? category;
  final String? authorName;
  final String? authorAvatar;
  final bool isLiked;
  final bool isSaved;

  PostModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.localImageUrl,
    this.videoUrl,
    required this.publishedAt,
    this.likes = 0,
    this.comments = 0,
    this.category,
    this.authorName,
    this.authorAvatar,
    this.isLiked = false,
    this.isSaved = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json, {bool isLiked = false, bool isSaved = false}) {
    // Check nested author details if available (e.g. from global feed API)
    final authorJson = json['author'] as Map<String, dynamic>?;
    
    return PostModel(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String? ?? '',
      localImageUrl: json['localImageUrl'] as String?,
      videoUrl: json['videoUrl'] as String? ?? json['video_url'] as String?,
      publishedAt: json['publishedAt'] as String? ?? json['published_at'] as String? ?? DateTime.now().toIso8601String(),
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      category: json['category'] as String?,
      authorName: authorJson != null ? (authorJson['name'] as String?) : json['authorName'] as String?,
      authorAvatar: authorJson != null
          ? (authorJson['profile_picture'] as String? ??
              authorJson['profilePicture'] as String? ??
              authorJson['avatar'] as String? ??
              authorJson['image'] as String?)
          : json['authorAvatar'] as String?,
      isLiked: isLiked,
      isSaved: isSaved,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'localImageUrl': localImageUrl,
      'videoUrl': videoUrl,
      'publishedAt': publishedAt,
      'likes': likes,
      'comments': comments,
      'category': category,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'isLiked': isLiked,
      'isSaved': isSaved,
    };
  }

  // Convert to Drift Global Feed DB Row
  GlobalFeedData toDriftGlobal() {
    return GlobalFeedData(
      id: id,
      slug: slug,
      title: title,
      description: description,
      imageUrl: imageUrl,
      localImageUrl: localImageUrl,
      publishedAt: publishedAt,
      likes: likes,
      comments: comments,
      category: category,
      authorName: authorName,
      authorAvatar: authorAvatar,
    );
  }

  // Create from Drift Global Feed DB Row
  factory PostModel.fromDriftGlobal(GlobalFeedData post) {
    return PostModel(
      id: post.id,
      slug: post.slug ?? '',
      title: post.title ?? '',
      description: post.description ?? '',
      imageUrl: post.imageUrl ?? '',
      localImageUrl: post.localImageUrl,
      publishedAt: post.publishedAt ?? '',
      likes: post.likes,
      comments: post.comments,
      category: post.category,
      authorName: post.authorName,
      authorAvatar: post.authorAvatar,
    );
  }

  // Convert to Drift Local User Posts DB Row
  LocalPost toDriftLocal() {
    return LocalPost(
      id: id,
      slug: slug,
      title: title,
      description: description,
      imageUrl: imageUrl,
      localImageUrl: localImageUrl,
      publishedAt: publishedAt,
      likes: likes,
      comments: comments,
      category: category,
    );
  }

  // Create from Drift Local User Posts DB Row
  factory PostModel.fromDriftLocal(LocalPost post) {
    return PostModel(
      id: post.id,
      slug: post.slug ?? '',
      title: post.title ?? '',
      description: post.description ?? '',
      imageUrl: post.imageUrl ?? '',
      localImageUrl: post.localImageUrl,
      publishedAt: post.publishedAt ?? '',
      likes: post.likes,
      comments: post.comments,
      category: post.category,
    );
  }
}
