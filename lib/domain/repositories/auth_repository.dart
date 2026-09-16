import 'package:supabase_flutter/supabase_flutter.dart';
import '../entities/user.dart';

/// Abstract contract for Authentication operations.
/// The Domain Layer depends on this interface, while the Data Layer implements it.
abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;
  
  User? get currentSupabaseUser;

  Future<void> updateFcmToken(String token);
  
  Future<UserModel?> getCurrentUserProfile({bool forceRefresh = false});
  
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  });
  
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });
  
  Future<void> signInWithGoogle();
  
  Future<void> signInWithGithub();
  
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
  });
  
  Future<void> signOut();
  
  Future<UserModel?> getUserProfile(String userId);
  
  Future<bool> isFollowingUser(String currentUserId, String targetUserId);
  
  Future<bool> toggleFollowUser(String currentUserId, String targetUserId, bool isFollowing);
  
  Future<List<Map<String, dynamic>>> getFollowers(String userId);
  
  Future<List<Map<String, dynamic>>> getFollowing(String userId);

  // Settings synchronizations
  Future<void> updateNotificationSettings({
    required bool notifyLikes,
    required bool notifyComments,
    required bool notifyMentions,
    required bool notifyNewPosts,
  });
  Future<void> updateAccountPrivacy(bool isPrivate);
  Future<void> updateActivityStatus(bool showActivityStatus);
  Future<void> updateInteractionPrivacy({String? commentPrivacy, String? mentionPrivacy});
  Future<void> updateCallPrivacy(String callPrivacy);
  Future<void> updateCallQuality(String callQuality);

  // User Blocking
  Future<void> blockUser(String targetUserId);
  Future<void> unblockUser(String targetUserId);
  Future<List<Map<String, dynamic>>> getBlockedUsers();

  // Follow Requests
  Future<List<Map<String, dynamic>>> getFollowRequests();
  Future<void> respondToFollowRequest(String requestId, String followerId, bool accept);

  // Notifications
  Future<List<Map<String, dynamic>>> getNotifications();
  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();
  Future<void> dismissNotification(String notificationId);

  // Calls
  Future<List<UserModel>> getEligibleCallUsers();
}
