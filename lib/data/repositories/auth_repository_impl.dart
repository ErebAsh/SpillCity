import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:spillcity/data/database/local_db.dart';
import 'package:spillcity/domain/entities/user.dart';
import 'package:spillcity/services/preferences_service.dart';

import 'package:spillcity/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabase _db;
  final PreferencesService _prefs = PreferencesService.instance;

  AuthRepositoryImpl(this._db);

  // Stream tracking Supabase Auth States
  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentSupabaseUser => _client.auth.currentUser;

  @override
  Future<void> updateFcmToken(String token) async {
    final user = currentSupabaseUser;
    if (user == null) return;
    try {
      await _client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  @override
  Future<UserModel?> getCurrentUserProfile({bool forceRefresh = false}) async {
    final user = currentSupabaseUser;
    if (user == null) return null;

    try {
      // Sync FCM token in background
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await updateFcmToken(token);
        }
      } catch (_) {}

      // 1. Try reading from local cache database if not forcing refresh
      if (!forceRefresh) {
        final localProfile = await _db.getLocalProfile(user.id);
        if (localProfile != null) {
          return UserModel.fromDrift(localProfile);
        }
      }

      // 2. Fetch from Supabase Remote Database
      final response = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        final userModel = UserModel.fromJson(response);
        // Sync to local cache
        await _db.saveUserProfile(userModel.toDrift());
        return userModel;
      }
    } catch (e) {
      // Return local cache if network is down
      final localProfile = await _db.getLocalProfile(user.id);
      if (localProfile != null) {
        return UserModel.fromDrift(localProfile);
      }
    }
    return null;
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );

    if (response.user != null) {
      // Insert profile record into public.users table on the backend
      try {
        await _client.from('users').insert({
          'id': response.user!.id,
          'name': name,
          'email': email,
          'onboarding_complete': false,
          'password': password,
        });
      } catch (e) {
        // Ignore error if profile record already exists/was inserted by a database trigger
        debugPrint('Profile insert skipped or failed (possibly handled by db trigger): $e');
      }

      // Save initial profile locally
      final newUser = UserModel(
        id: response.user!.id,
        name: name,
        email: email,
        onboardingComplete: false,
      );
      await _db.saveUserProfile(newUser.toDrift());
    }

    return response;
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Fetch user profile and save locally
      await getCurrentUserProfile();
    }

    return response;
  }

  @override
  Future<void> signInWithGoogle() async {
    final success = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'proxypress://login-callback/',
    );
    if (success) {
      await getCurrentUserProfile();
    }
  }

  @override
  Future<void> signInWithGithub() async {
    final success = await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'proxypress://login-callback/',
    );
    if (success) {
      await getCurrentUserProfile();
    }
  }

  @override
  Future<void> completeOnboarding({
    required String name,
    required String username,
    required String bio,
    required String college,
    String? branch,
    String? department,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? links,
    String? profilePicture,
  }) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    // Fetch existing user profile to preserve avatar/profile_picture if not provided
    final existingProfile = await getCurrentUserProfile();
    final finalProfilePicture = profilePicture ?? existingProfile?.profilePicture;
    final finalAvatar = finalProfilePicture ?? existingProfile?.avatar ?? '👤';

    final updates = {
      'id': user.id,
      'email': user.email,
      'name': name,
      'username': username,
      'bio': bio,
      'college': college,
      'branch': branch,
      'department': department,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'links': links,
      'profile_picture': finalProfilePicture,
      'avatar': finalAvatar,
      'onboarding_complete': true,
    };

    // 1. Upsert backend database (creates record if missing, updates if exists)
    await _client.from('users').upsert(updates);

    // 2. Fetch fresh profile and cache locally
    final updatedProfile = await _client
        .from('users')
        .select()
        .eq('id', user.id)
        .single();
    
    final userModel = UserModel.fromJson(updatedProfile);
    await _db.saveUserProfile(userModel.toDrift());
  }

  @override
  Future<void> signOut() async {
    // 1. Supabase Sign Out
    await _client.auth.signOut();
    
    // 2. Clear Local Cache SQLite database
    await _db.clearGlobalFeed();
    // Delete profile rows
    await _db.delete(_db.localUserProfiles).go();
    await _db.delete(_db.localMessages).go();
    await _db.delete(_db.localPosts).go();
    await _db.delete(_db.pendingPosts).go();
    await _db.delete(_db.exploreFeed).go();

    // 3. Clear SharedPreferences
    await _prefs.clearAll();
  }

  @override
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return UserModel.fromJson(response);
      }
    } catch (e) {
      // Return null or handle error
    }
    return null;
  }

  @override
  Future<bool> isFollowingUser(String currentUserId, String targetUserId) async {
    try {
      final response = await _client
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> toggleFollowUser(String currentUserId, String targetUserId, bool isFollowing) async {
    try {
      if (isFollowing) {
        await _client
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', targetUserId);
        return false;
      } else {
        await _client.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': targetUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      return isFollowing;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      final response = await _client
          .from('follows')
          .select('follower:users!follower_id(id, name, username, avatar, profile_picture)')
          .eq('following_id', userId);
      
      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((item) {
        final follower = item['follower'] as Map<String, dynamic>? ?? {};
        return follower;
      }).toList();
    } catch (e) {
      debugPrint('Error getting followers: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      final response = await _client
          .from('follows')
          .select('following:users!following_id(id, name, username, avatar, profile_picture)')
          .eq('follower_id', userId);
      
      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((item) {
        final following = item['following'] as Map<String, dynamic>? ?? {};
        return following;
      }).toList();
    } catch (e) {
      debugPrint('Error getting following: $e');
      return [];
    }
  }

  // ─── Settings Synchronizations ───

  @override
  Future<void> updateNotificationSettings({
    required bool notifyLikes,
    required bool notifyComments,
    required bool notifyMentions,
    required bool notifyNewPosts,
  }) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    final updates = {
      'notify_likes': notifyLikes,
      'notify_comments': notifyComments,
      'notify_mentions': notifyMentions,
      'notify_new_posts': notifyNewPosts,
    };

    await _client.from('users').update(updates).eq('id', user.id);
    await getCurrentUserProfile(forceRefresh: true); // Force refresh local cached profile
  }

  @override
  Future<void> updateAccountPrivacy(bool isPrivate) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    await _client.from('users').update({'is_private': isPrivate}).eq('id', user.id);
    await getCurrentUserProfile(forceRefresh: true);
  }

  @override
  Future<void> updateActivityStatus(bool showActivityStatus) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    await _client.from('users').update({'show_activity_status': showActivityStatus}).eq('id', user.id);
    await getCurrentUserProfile(forceRefresh: true);
  }

  @override
  Future<void> updateInteractionPrivacy({
    String? commentPrivacy,
    String? mentionPrivacy,
  }) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    final updates = <String, dynamic>{};
    if (commentPrivacy != null) updates['comment_privacy'] = commentPrivacy;
    if (mentionPrivacy != null) updates['mention_privacy'] = mentionPrivacy;

    await _client.from('users').update(updates).eq('id', user.id);
    await getCurrentUserProfile(forceRefresh: true);
  }

  @override
  Future<void> updateCallPrivacy(String callPrivacy) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    await _client.from('users').update({'call_privacy': callPrivacy}).eq('id', user.id);
    await getCurrentUserProfile(forceRefresh: true);
  }

  @override
  Future<void> updateCallQuality(String callQuality) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    await _client.from('users').update({'call_quality': callQuality}).eq('id', user.id);
    await getCurrentUserProfile(forceRefresh: true);
  }

  // ─── User Blocking / Moderation ───

  @override
  Future<void> blockUser(String targetUserId) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    await _client.from('user_blocks').insert({
      'user_id': user.id,
      'blocked_id': targetUserId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> unblockUser(String targetUserId) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    await _client.from('user_blocks')
        .delete()
        .eq('user_id', user.id)
        .eq('blocked_id', targetUserId);
  }

  @override
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final user = currentSupabaseUser;
    if (user == null) return [];

    final response = await _client
        .from('user_blocks')
        .select('blocked_id, blocked_user:users!blocked_id(id, name, username, avatar)')
        .eq('user_id', user.id);

    return List<Map<String, dynamic>>.from(response as List);
  }

  // ─── Follow Requests Management ───

  @override
  Future<List<Map<String, dynamic>>> getFollowRequests() async {
    final user = currentSupabaseUser;
    if (user == null) return [];

    final response = await _client
        .from('follow_requests')
        .select('id, follower:users!follower_id(id, name, username, avatar)')
        .eq('following_id', user.id);

    return List<Map<String, dynamic>>.from(response as List);
  }

  @override
  Future<void> respondToFollowRequest(String requestId, String followerId, bool accept) async {
    final user = currentSupabaseUser;
    if (user == null) throw Exception("User not authenticated");

    if (accept) {
      // 1. Create Follow
      await _client.from('follows').insert({
        'follower_id': followerId,
        'following_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Create Notification for the follower
      try {
        await _client.from('notifications').insert({
          'id': 'ntf-fra-$requestId',
          'user_id': followerId,
          'actor_id': user.id,
          'type': 'follow_accept',
          'message': 'accepted your follow request',
          'time_ago': 'just now',
          'created_at': DateTime.now().toIso8601String(),
          'is_read': false,
        });
      } catch (_) {
        // Suppress notification insert errors if notification row fails
      }
    }

    // 3. Delete Request
    await _client.from('follow_requests').delete().eq('id', requestId);
  }

  // ─── Notifications Management ───

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = currentSupabaseUser;
    if (user == null) return [];

    try {
      // Fetch user blocks & mutes in parallel to filter notifications
      final mutesResponse = await _client.from('user_mutes').select('muted_id').eq('user_id', user.id);
      final blocksResponse = await _client.from('user_blocks').select('blocked_id').eq('user_id', user.id);

      final excludedUserIds = <String>[];
      for (var row in (mutesResponse as List)) {
        excludedUserIds.add(row['muted_id'] as String);
      }
      for (var row in (blocksResponse as List)) {
        excludedUserIds.add(row['blocked_id'] as String);
      }

      var query = _client
          .from('notifications')
          .select('''
            id, type, message, time_ago, created_at, is_read, post_id,
            actor:users!actor_id ( id, name, avatar, profile_picture ),
            post:posts!post_id ( id, title )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final response = await query;
      final list = List<Map<String, dynamic>>.from(response as List);

      // Filter out excluded user notifications client-side or check if query supports exclusion
      if (excludedUserIds.isNotEmpty) {
        return list.where((notif) {
          final actor = notif['actor'] as Map<String, dynamic>?;
          if (actor == null) return true;
          return !excludedUserIds.contains(actor['id']);
        }).toList();
      }

      return list;
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final user = currentSupabaseUser;
    if (user == null) return;

    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  @override
  Future<void> dismissNotification(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
    }
  }

  @override
  Future<List<UserModel>> getEligibleCallUsers() async {
    final user = currentSupabaseUser;
    if (user == null) return [];

    try {
      // 1. Fetch users we follow (following)
      final followingResponse = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id);
      
      final followingIds = (followingResponse as List)
          .map((item) => item['following_id'] as String)
          .toSet();

      if (followingIds.isEmpty) return [];

      // 2. Fetch users who follow us (followers)
      final followersResponse = await _client
          .from('follows')
          .select('follower_id')
          .eq('following_id', user.id);
      
      final followerIds = (followersResponse as List)
          .map((item) => item['follower_id'] as String)
          .toSet();

      // 3. Find the mutual follows intersection
      final mutualIds = followingIds.intersection(followerIds);
      if (mutualIds.isEmpty) return [];

      // 4. Fetch conversation participants we have chat history with
      // First, get all conversation IDs that current user is part of
      final myConvsResponse = await _client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', user.id);
      
      final myConvIds = (myConvsResponse as List)
          .map((item) => item['conversation_id'] as String)
          .toList();

      if (myConvIds.isEmpty) return [];

      // Next, find other user IDs in those conversations who are also mutual follows
      final participantsResponse = await _client
          .from('conversation_participants')
          .select('user:users(id, name, username, avatar, profile_picture)')
          .inFilter('conversation_id', myConvIds)
          .neq('user_id', user.id);

      final List<UserModel> eligibleUsers = [];
      final Set<String> addedUserIds = {};

      for (var item in (participantsResponse as List)) {
        final userMap = item['user'] as Map<String, dynamic>?;
        if (userMap != null) {
          final matchedUser = UserModel.fromJson(userMap);
          if (mutualIds.contains(matchedUser.id) && !addedUserIds.contains(matchedUser.id)) {
            eligibleUsers.add(matchedUser);
            addedUserIds.add(matchedUser.id);
          }
        }
      }

      return eligibleUsers;
    } catch (e) {
      debugPrint('Error getting eligible call users: $e');
      return [];
    }
  }
}

