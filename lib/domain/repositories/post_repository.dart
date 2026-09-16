import 'package:spillcity/domain/entities/post.dart';
import 'package:spillcity/data/database/local_db.dart';

abstract class PostRepository {
  Future<List<PostModel>> getHomeFeed({String? userId, int limit = 10, int offset = 0});
  
  Future<void> toggleLike(String postId, String userId);
  
  Future<void> toggleSave(String postId, String userId);
  
  Future<List<PostModel>> getUserPosts(String userId);
  
  Future<List<PostModel>> getSavedPosts(String userId);
  
  Future<void> saveDraft({
    required String id,
    required String title,
    required String description,
    required String category,
    String? localImageUrl,
  });
  
  Future<List<PendingPost>> getDrafts();
  
  Future<Map<String, dynamic>?> getPostDetailBySlug(String slug, String? currentUserId);
  
  Future<Map<String, dynamic>?> addPostComment({
    required String postId,
    required String userId,
    required String text,
    String? parentId,
  });
  
  Future<Map<String, dynamic>> toggleCommentLike(String commentId, String userId);
  
  Future<PostModel?> getPostById(String id);
  
  Future<void> updatePost(String id, {
    required String title,
    required String description,
    required String category,
    required String imageUrl,
    String? videoUrl,
  });
  
  Future<void> deleteDraft(String id);
}
