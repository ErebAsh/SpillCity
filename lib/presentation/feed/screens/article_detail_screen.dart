import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/domain/entities/post.dart';
import '../widgets/post_card.dart';

class ArticleDetailScreen extends ConsumerStatefulWidget {
  final String slug;

  const ArticleDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends ConsumerState<ArticleDetailScreen> {
  final _commentController = TextEditingController();
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isLoading = true;
  Map<String, dynamic>? _detailData;
  bool _scrolledPastTitle = false;
  String? _activeReplyId;

  @override
  void initState() {
    super.initState();
    _loadArticle();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      // If we scroll down past 120px, set scrolledPastTitle to true
      final hasScrolled = _scrollController.offset > 120;
      if (hasScrolled != _scrolledPastTitle) {
        setState(() {
          _scrolledPastTitle = hasScrolled;
        });
      }
    }
  }

  Future<void> _loadArticle() async {
    setState(() => _isLoading = true);
    final user = ref.read(authRepositoryProvider).currentSupabaseUser;
    final data = await ref.read(postRepositoryProvider).getPostDetailBySlug(widget.slug, user?.id);
    if (mounted) {
      setState(() {
        _detailData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePostComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authRepositoryProvider).currentSupabaseUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to comment')),
      );
      return;
    }

    final post = _detailData?['post'] as PostModel?;
    if (post == null) return;

    try {
      final result = await ref.read(postRepositoryProvider).addPostComment(
            postId: post.id,
            userId: user.id,
            text: text,
          );

      if (result != null && result['success'] == true) {
        _commentController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
        }
        _loadArticle(); // Refresh comments list
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment')),
        );
        }
      }
    } catch (e) {
      debugPrint("Comment post error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
      }
    }
  }

  Future<void> _handlePostReply(String parentId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authRepositoryProvider).currentSupabaseUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to reply')),
      );
      return;
    }

    final post = _detailData?['post'] as PostModel?;
    if (post == null) return;

    try {
      final result = await ref.read(postRepositoryProvider).addPostComment(
            postId: post.id,
            userId: user.id,
            text: text,
            parentId: parentId,
          );

      if (result != null && result['success'] == true) {
        _replyController.clear();
        setState(() {
          _activeReplyId = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply posted!')),
        );
        }
        _loadArticle(); // Refresh comments list
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post reply')),
        );
        }
      }
    } catch (e) {
      debugPrint("Reply post error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post reply: $e')),
      );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final user = ref.read(authRepositoryProvider).currentSupabaseUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like comments')),
      );
      return;
    }

    final result = await ref.read(postRepositoryProvider).toggleCommentLike(commentId, user.id);
    if (result['success'] == true) {
      _loadArticle(); // Reload to show updated likes count
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading article...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (_detailData == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: Text('Article not found.'),
        ),
      );
    }

    final post = _detailData!['post'] as PostModel;
    final content = _detailData!['content'] as String;
    final author = _detailData!['author'] as Map<String, dynamic>?;
    final related = _detailData!['related'] as List<PostModel>;
    final canComment = _detailData!['canComment'] as bool;
    final rawComments = _detailData!['comments'] as List<dynamic>;

    // Filter parent comments & replies
    final parentComments = rawComments.where((c) => c['parent_id'] == null).toList();
    final replies = rawComments.where((c) => c['parent_id'] != null).toList();

    final categoryColor = categoryColors[post.category ?? 'News'] ?? const Color(0xFF6366F1);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: AnimatedOpacity(
          opacity: _scrolledPastTitle ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            post.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Share link / title
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Article link copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                post.category?.toUpperCase() ?? 'NEWS',
                style: TextStyle(
                  color: categoryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              post.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Author metadata row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: () {
                    final avatarUrl = author?['profile_picture'] as String? ?? author?['avatar'] as String? ?? '';
                    if (avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com')) {
                      return NetworkImage(avatarUrl);
                    }
                    return null;
                  }(),
                  child: () {
                    final avatarUrl = author?['profile_picture'] as String? ?? author?['avatar'] as String? ?? '';
                    if (avatarUrl.isEmpty || !avatarUrl.startsWith('http') || avatarUrl.contains('ui-avatars.com')) {
                      return Text(
                        avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                            ? avatarUrl
                            : (author?['name'] as String? ?? 'U')[0].toUpperCase(),
                      );
                    }
                    return null;
                  }(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author?['name'] as String? ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${author?['college'] ?? 'Campus'} · ${_formatPublishedAt(post.publishedAt)}',
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Hero Image
            if (post.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(color: Colors.grey[300], height: 200),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 24),

            // Description (italic / bold lead)
            if (post.description.isNotEmpty) ...[
              Text(
                post.description,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Content Body paragraphs
            Text(
              content.isNotEmpty ? content : 'No content available.',
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 24),

            // Engagement Row
            Row(
              children: [
                Icon(Icons.thumb_up_alt_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${post.likes} likes',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 16),
                Icon(Icons.comment_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${post.comments} comments',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const Divider(height: 32),

            // Comments Header
            Text(
              'Comments (${post.comments})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Comment textfield
            if (canComment) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _handlePostComment,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Comments are restricted by the author.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),

            // Comments list builder
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: parentComments.length,
              itemBuilder: (context, index) {
                final comment = parentComments[index];
                final commentId = comment['id'] as String;
                final commentUser = comment['user'] as Map<String, dynamic>?;
                final commentLikes = comment['likes'] as List<dynamic>? ?? [];
                
                final threadReplies = replies.where((r) => r['parent_id'] == commentId).toList();
                final isLikedByMe = ref.read(authRepositoryProvider).currentSupabaseUser != null &&
                    commentLikes.any((l) => l['user_id'] == ref.read(authRepositoryProvider).currentSupabaseUser!.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Comment Item Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: () {
                              final avatarUrl = commentUser?['profile_picture'] as String? ?? commentUser?['avatar'] as String? ?? '';
                              if (avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com')) {
                                return NetworkImage(avatarUrl);
                              }
                              return null;
                            }(),
                            child: () {
                              final avatarUrl = commentUser?['profile_picture'] as String? ?? commentUser?['avatar'] as String? ?? '';
                              if (avatarUrl.isEmpty || !avatarUrl.startsWith('http') || avatarUrl.contains('ui-avatars.com')) {
                                return Text(
                                  avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                                      ? avatarUrl
                                      : (commentUser?['name'] as String? ?? 'U')[0].toUpperCase(),
                                );
                              }
                              return null;
                            }(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    text: '${commentUser?['name'] ?? 'User'}  ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _formatPublishedAt(comment['created_at'] as String),
                                        style: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['text'] as String? ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 8),

                                // Reply / Like buttons
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _activeReplyId = _activeReplyId == commentId ? null : commentId;
                                          if (_activeReplyId != null) {
                                            _replyController.text = '@${commentUser?['name']?.toString().replaceAll(' ', '') ?? 'user'} ';
                                          }
                                        });
                                      },
                                      child: Text(
                                        'Reply',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => _toggleCommentLike(commentId),
                                      child: Text(
                                        isLikedByMe ? '❤️ Liked' : '🤍 Like',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isLikedByMe ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                    if (commentLikes.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '${commentLikes.length}',
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Thread replies rendering
                      if (threadReplies.isNotEmpty || _activeReplyId == commentId)
                        Padding(
                          padding: const EdgeInsets.only(left: 24.0, top: 12.0),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.only(left: 14.0),
                            child: Column(
                              children: [
                                // Loop existing replies
                                ...threadReplies.map((rep) {
                                  final repUser = rep['user'] as Map<String, dynamic>?;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundImage: () {
                                            final avatarUrl = repUser?['profile_picture'] as String? ?? repUser?['avatar'] as String? ?? '';
                                            if (avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com')) {
                                              return NetworkImage(avatarUrl);
                                            }
                                            return null;
                                          }(),
                                          child: () {
                                            final avatarUrl = repUser?['profile_picture'] as String? ?? repUser?['avatar'] as String? ?? '';
                                            if (avatarUrl.isEmpty || !avatarUrl.startsWith('http') || avatarUrl.contains('ui-avatars.com')) {
                                              return Text(
                                                avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                                                    ? avatarUrl
                                                    : (repUser?['name'] as String? ?? 'U')[0].toUpperCase(),
                                                style: const TextStyle(fontSize: 10),
                                              );
                                            }
                                            return null;
                                          }(),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  text: '${repUser?['name'] ?? 'User'}  ',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurface,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: _formatPublishedAt(rep['created_at'] as String),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.normal,
                                                        fontSize: 10,
                                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                rep['text'] as String? ?? '',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                // Reply box inline if active
                                if (_activeReplyId == commentId)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _replyController,
                                          autofocus: true,
                                          maxLines: null,
                                          decoration: InputDecoration(
                                            hintText: 'Reply to conversation...',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.send),
                                        onPressed: () => _handlePostReply(commentId),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const Divider(height: 48),

            // Related Posts
            if (related.isNotEmpty) ...[
              const Text(
                'Related Stories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...related.map((rp) => PostCard(
                    post: rp,
                    onTap: () {
                      context.push('/article/${rp.slug}');
                    },
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPublishedAt(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Recently';
    }
  }
}
