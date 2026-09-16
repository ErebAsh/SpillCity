import 'package:spillcity/domain/entities/post.dart';
import '../../repositories/post_repository.dart';

class FetchFeedUseCase {
  final PostRepository repository;

  FetchFeedUseCase(this.repository);

  Future<List<PostModel>> execute({String? userId, int limit = 10, int offset = 0}) {
    return repository.getHomeFeed(userId: userId, limit: limit, offset: offset);
  }
}
