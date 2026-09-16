import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/data/database/local_db.dart';
import 'package:spillcity/domain/entities/user.dart';
import 'cloudinary_service.dart';

class SyncService {
  final LocalDatabase _db;
  final SupabaseClient _client = Supabase.instance.client;
  bool _isSyncing = false;

  SyncService(this._db);

  /// Run sync routines for all user profile, post feeds, and local drafts
  Future<void> syncAllUserData(String userId) async {
    if (_isSyncing) return;
    _isSyncing = true;

    debugPrint("[SyncService] Starting sync cycle for user: $userId");
    try {
      // 1. Sync User Profile from Supabase
      final profileResponse = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null) {
        final userModel = UserModel.fromJson(profileResponse);
        await _db.saveUserProfile(userModel.toDrift());
        debugPrint("[SyncService] Cached profile details successfully.");
      }

      // 2. Flush any pending draft posts queued offline
      await flushPendingPosts();

    } catch (e) {
      debugPrint("[SyncService] Sync cycle encountered an error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  /// Flushes all locally saved pending posts/drafts to the remote Supabase database
  Future<void> flushPendingPosts() async {
    try {
      final pendingDrafts = await _db.select(_db.pendingPosts).get();
      if (pendingDrafts.isEmpty) {
        debugPrint("[SyncService] No pending offline posts found to flush.");
        return;
      }

      debugPrint("[SyncService] Found ${pendingDrafts.length} offline posts. Initializing upload...");

      for (final draft in pendingDrafts) {
        try {
          final title = draft.title ?? '';
          final description = draft.description ?? '';
          final category = draft.category ?? 'Others';
          final localPath = draft.localImageUrl;

          String mediaUrl = 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=80';
          String? videoUrl;

          // Upload cover image/media if a local file exists
          if (localPath != null && localPath.isNotEmpty) {
            final mediaFile = File(localPath);
            if (await mediaFile.exists()) {
              final isVideo = localPath.endsWith('.mp4');
              final category = isVideo ? 'videos' : 'images';
              final publicUrl = await CloudinaryService.uploadMedia(
                file: mediaFile,
                category: category,
              );

              if (isVideo) {
                videoUrl = publicUrl;
              } else {
                mediaUrl = publicUrl;
              }
            }
          }

          // Insert the post to Supabase
          final currentUserId = _client.auth.currentUser?.id;
          if (currentUserId == null) continue;

          final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
          final postId = draft.id.startsWith('draft_')
              ? draft.id.replaceFirst('draft_', 'p')
              : 'p${DateTime.now().millisecondsSinceEpoch}';
          final slug = '${cleanTitle.isEmpty ? 'post' : cleanTitle}-$postId';

          await _client.from('posts').insert({
            'id': postId,
            'title': title,
            'description': description,
            'content': description,
            'category': category,
            'image_url': mediaUrl,
            'video_url': videoUrl,
            'author_id': currentUserId,
            'slug': slug,
            'image_color': 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
            'published_at': draft.createdAt ?? DateTime.now().toUtc().toIso8601String(),
          });

          // Delete draft from SQLite upon successful remote insertion
          await (_db.delete(_db.pendingPosts)..where((t) => t.id.equals(draft.id))).go();
          debugPrint("[SyncService] ✓ Sync Complete: '$title' published and deleted from draft cache.");

        } catch (e) {
          debugPrint("[SyncService] ✗ Failed to sync draft post: $e");
          // Stop flushing subsequent posts to preserve order and retry later when connectivity improves
          break;
        }
      }
    } catch (e) {
      debugPrint("[SyncService] Error loading drafts from local SQLite DB: $e");
    }
  }
}
