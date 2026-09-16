import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/data/database/local_db.dart';
import 'package:spillcity/domain/entities/post.dart';

import 'package:spillcity/domain/repositories/post_repository.dart';

class PostRepositoryImpl implements PostRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabase _db;

  PostRepositoryImpl(this._db);

  @override
  Future<List<PostModel>> getHomeFeed({String? userId, int limit = 10, int offset = 0}) async {
    try {
      // 1. Query Supabase
      final response = await _client
          .from('posts')
          .select('''
            id, slug, title, description, image_url, video_url, published_at, likes, comments, category,
            author:users ( id, name, avatar, profile_picture )
          ''')
          .order('published_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List<dynamic>? ?? [];
      
      // Fetch user's likes and saves for these posts to determine liked/saved state
      final myId = _client.auth.currentUser?.id;
      final List<String> likedPostIds = [];
      final List<String> savedPostIds = [];

      if (myId != null && data.isNotEmpty) {
        final postIds = data.map((p) => p['id'] as String).toList();
        
        try {
          final likesResponse = await _client
              .from('post_likes')
              .select('post_id')
              .eq('user_id', myId)
              .inFilter('post_id', postIds);
          for (var item in likesResponse as List<dynamic>) {
            likedPostIds.add(item['post_id'] as String);
          }
                } catch (e) {
          debugPrint('Error loading user likes: $e');
        }

        try {
          final savesResponse = await _client
              .from('post_saves')
              .select('post_id')
              .eq('user_id', myId)
              .inFilter('post_id', postIds);
          for (var item in savesResponse as List<dynamic>) {
            savedPostIds.add(item['post_id'] as String);
          }
                } catch (e) {
          debugPrint('Error loading user saves: $e');
        }
      }

      final List<PostModel> posts = data.map((json) {
        final postId = json['id'] as String;
        return PostModel.fromJson(
          json as Map<String, dynamic>,
          isLiked: likedPostIds.contains(postId),
          isSaved: savedPostIds.contains(postId),
        );
      }).toList();

      // 2. Cache first page locally
      if (offset == 0 && posts.isNotEmpty) {
        await _db.clearGlobalFeed();
        for (var post in posts) {
          await _db.saveGlobalPost(post.toDriftGlobal());
        }
      }

      return posts;
    } catch (e) {
      // 3. Offline fallback (only for first page)
      if (offset == 0) {
        final cached = await _db.getGlobalFeed();
        if (cached.isNotEmpty) {
          return cached.map((p) => PostModel.fromDriftGlobal(p)).toList();
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> toggleLike(String postId, String userId) async {
    try {
      final existing = await _client
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        
        // Decrement likes count on posts table
        try {
          final post = await _client.from('posts').select('likes').eq('id', postId).single();
          final currentLikes = (post['likes'] as int? ?? 0);
          await _client.from('posts').update({
            'likes': currentLikes > 0 ? currentLikes - 1 : 0,
          }).eq('id', postId);
        } catch (_) {}
      } else {
        await _client.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });

        // Increment likes count on posts table
        try {
          final post = await _client.from('posts').select('likes').eq('id', postId).single();
          final currentLikes = (post['likes'] as int? ?? 0);
          await _client.from('posts').update({
            'likes': currentLikes + 1,
          }).eq('id', postId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Failed to toggle like: $e');
    }
  }

  @override
  Future<void> toggleSave(String postId, String userId) async {
    try {
      final existing = await _client
          .from('post_saves')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('post_saves')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await _client.from('post_saves').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
    } catch (e) {
      debugPrint('Failed to toggle save: $e');
    }
  }

  @override
  Future<List<PostModel>> getUserPosts(String userId) async {
    final response = await _client
        .from('posts')
        .select('''
          id, slug, title, description, image_url, video_url, published_at, likes, comments, category,
          author:users ( id, name, avatar, profile_picture )
        ''')
        .eq('author_id', userId)
        .order('published_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>? ?? [];
    return data.map((json) => PostModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PostModel>> getSavedPosts(String userId) async {
    final response = await _client
        .from('post_saves')
        .select('''
          post:posts (
            id, slug, title, description, image_url, video_url, published_at, likes, comments, category,
            author:users ( id, name, avatar, profile_picture )
          )
        ''')
        .eq('user_id', userId);

    final List<dynamic> data = response as List<dynamic>? ?? [];
    final List<PostModel> posts = [];
    for (var item in data) {
      if (item['post'] != null) {
        posts.add(PostModel.fromJson(item['post'] as Map<String, dynamic>));
      }
    }
    return posts;
  }

  @override
  Future<void> saveDraft({
    required String id,
    required String title,
    required String description,
    required String category,
    String? localImageUrl,
  }) async {
    await _db.into(_db.pendingPosts).insertOnConflictUpdate(
      PendingPost(
        id: id,
        title: title,
        description: description,
        category: category,
        localImageUrl: localImageUrl,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<List<PendingPost>> getDrafts() async {
    return await _db.select(_db.pendingPosts).get();
  }

  @override
  Future<Map<String, dynamic>?> getPostDetailBySlug(String slug, String? currentUserId) async {
    try {
      var postResponse = await _client
          .from('posts')
          .select('''
            id, slug, title, description, content, image_url, video_url, published_at, likes, comments, category, author_id,
            author:users ( id, name, avatar, profile_picture, college, comment_privacy )
          ''')
          .eq('slug', slug)
          .maybeSingle();

      postResponse ??= await _client
            .from('posts')
            .select('''
              id, slug, title, description, content, image_url, video_url, published_at, likes, comments, category, author_id,
              author:users ( id, name, avatar, profile_picture, college, comment_privacy )
            ''')
            .eq('id', slug)
            .maybeSingle();

      if (postResponse == null) return null;

      final postMap = Map<String, dynamic>.from(postResponse);
      final authorMap = postMap['author'] as Map<String, dynamic>?;
      final String authorId = postMap['author_id'] as String;
      final String postId = postMap['id'] as String;
      final String category = postMap['category'] as String? ?? 'News';

      // Related posts
      final relatedResponse = await _client
          .from('posts')
          .select('''
            id, slug, title, description, image_url, video_url, published_at, likes, comments, category,
            author:users ( id, name, avatar, profile_picture )
          ''')
          .eq('category', category)
          .neq('id', postId)
          .limit(3);

      final List<dynamic> relatedData = relatedResponse as List<dynamic>? ?? [];
      final List<PostModel> relatedPosts = relatedData.map((json) => PostModel.fromJson(json as Map<String, dynamic>)).toList();

      // Comment Privacy Check
      bool canComment = true;
      final String privacy = authorMap?['comment_privacy'] as String? ?? 'Everyone';
      if (privacy == 'No One') {
        canComment = false;
      } else if (privacy == 'People You Follow') {
        if (currentUserId == null) {
          canComment = false;
        } else if (authorId != currentUserId) {
          final follow = await _client
              .from('follows')
              .select()
              .eq('follower_id', authorId)
              .eq('following_id', currentUserId)
              .maybeSingle();
          if (follow == null) canComment = false;
        }
      }

      // Comments List
      final commentsResponse = await _client
          .from('post_comments')
          .select('''
            id, post_id, user_id, text, parent_id, created_at,
            user:users ( id, name, avatar, profile_picture ),
            likes:comment_likes ( comment_id, user_id )
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      final List<dynamic> commentsData = commentsResponse as List<dynamic>? ?? [];

      return {
        'post': PostModel.fromJson(postMap),
        'content': postMap['content'] as String? ?? '',
        'author': authorMap,
        'related': relatedPosts,
        'canComment': canComment,
        'comments': commentsData,
      };
    } catch (e) {
      debugPrint('Error getting post detail: $e');
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> addPostComment({
    required String postId,
    required String userId,
    required String text,
    String? parentId,
  }) async {
    final id = 'comment-${DateTime.now().millisecondsSinceEpoch}';
    final newComment = {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'text': text,
      'parent_id': parentId,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from('post_comments').insert(newComment);
    
    // Increment comments count on posts table
    try {
      final post = await _client.from('posts').select('comments').eq('id', postId).single();
      final currentComments = (post['comments'] as int? ?? 0);
      await _client.from('posts').update({
        'comments': currentComments + 1,
      }).eq('id', postId);
    } catch (_) {}

    return {
      'success': true,
      'id': id,
    };
  }

  @override
  Future<Map<String, dynamic>> toggleCommentLike(String commentId, String userId) async {
    try {
      final existingLike = await _client
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        await _client
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      } else {
        await _client.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': userId,
        });
      }
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  @override
  Future<PostModel?> getPostById(String id) async {
    try {
      final response = await _client
          .from('posts')
          .select('''
            id, slug, title, description, image_url, video_url, published_at, likes, comments, category,
            author:users ( id, name, avatar, profile_picture )
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return PostModel.fromJson(response);
    } catch (e) {
      debugPrint('Error getting post by ID: $e');
      return null;
    }
  }

  @override
  Future<void> updatePost(String id, {
    required String title,
    required String description,
    required String category,
    required String imageUrl,
    String? videoUrl,
  }) async {
    await _client.from('posts').update({
      'title': title,
      'description': description,
      'content': description,
      'category': category,
      'image_url': imageUrl,
      'video_url': videoUrl,
    }).eq('id', id);
  }

  @override
  Future<void> deleteDraft(String id) async {
    await (_db.delete(_db.pendingPosts)..where((t) => t.id.equals(id))).go();
  }
}
