import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/data/database/local_db.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/post_repository.dart';
import 'auth_repository_impl.dart';
import 'post_repository_impl.dart';
import 'package:spillcity/domain/entities/user.dart';
import 'package:spillcity/domain/entities/post.dart';
import 'package:spillcity/services/sync_service.dart';

// Provide Local Database single instance
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final db = LocalDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Provide Authentication Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return AuthRepositoryImpl(db);
});

// Stream of Auth changes from Supabase (triggers UI navigation state changes)
final authStateProvider = StreamProvider((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

// Dynamic state provider for the currently logged-in user profile
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  
  // Re-evaluate when AuthState changes
  ref.watch(authStateProvider);
  
  return await authRepo.getCurrentUserProfile();
});

// Provide Post Repository
final postRepositoryProvider = Provider<PostRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return PostRepositoryImpl(db);
});

// Provide Home Feed Posts Future Provider
final homeFeedPostsProvider = FutureProvider.autoDispose<List<PostModel>>((ref) async {
  final repo = ref.watch(postRepositoryProvider);
  return await repo.getHomeFeed();
});

// Provide Sync Service
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return SyncService(db);
});

// Provide Real-time Unread Messages Count
final unreadMessageCountProvider = StreamProvider.autoDispose<int>((ref) {
  final supabaseClient = Supabase.instance.client;
  final currentUserId = supabaseClient.auth.currentUser?.id;
  if (currentUserId == null) return Stream.value(0);

  // Return periodic query stream which terminates on provider disposal
  return Stream.periodic(const Duration(seconds: 10), (count) => count)
      .asyncMap((_) async {
        try {
          final myParticipants = await supabaseClient
              .from('conversation_participants')
              .select('conversation_id')
              .eq('user_id', currentUserId);
          
          final List<dynamic> list = myParticipants as List<dynamic>? ?? [];
          final List<String> convIds = list.map((item) => item['conversation_id'] as String).toList();
          
          if (convIds.isEmpty) return 0;
          
          final response = await supabaseClient
              .from('messages')
              .select('id')
              .inFilter('conversation_id', convIds)
              .neq('sender_id', currentUserId)
              .eq('seen', false);
          
          final List<dynamic> data = response as List<dynamic>? ?? [];
          return data.length;
        } catch (e) {
          return 0;
        }
      });
});

// Provide currently active direct message conversation ID for hiding mobile footer
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

// Provide Notifications List Future Provider
final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return await repo.getNotifications();
});

// Provide Real-time Unread Notifications Count
final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final supabaseClient = Supabase.instance.client;
  final currentUserId = supabaseClient.auth.currentUser?.id;
  if (currentUserId == null) return Stream.value(0);

  // Return periodic query stream which terminates on provider disposal
  return Stream.periodic(const Duration(seconds: 10), (count) => count)
      .asyncMap((_) async {
        try {
          // Fetch user blocks & mutes in parallel to filter notification counts
          final mutesResponse = await supabaseClient.from('user_mutes').select('muted_id').eq('user_id', currentUserId);
          final blocksResponse = await supabaseClient.from('user_blocks').select('blocked_id').eq('user_id', currentUserId);

          final excludedUserIds = <String>[];
          for (var row in (mutesResponse as List)) {
            excludedUserIds.add(row['muted_id'] as String);
          }
          for (var row in (blocksResponse as List)) {
            excludedUserIds.add(row['blocked_id'] as String);
          }

          final response = await supabaseClient
              .from('notifications')
              .select('id, actor_id')
              .eq('user_id', currentUserId)
              .eq('is_read', false);
          
          final List<dynamic> list = response as List<dynamic>? ?? [];

          if (excludedUserIds.isNotEmpty) {
            final filtered = list.where((notif) {
              final actorId = notif['actor_id'] as String?;
              return actorId == null || !excludedUserIds.contains(actorId);
            });
            return filtered.length;
          }
          return list.length;
        } catch (e) {
          return 0;
        }
      });
});
