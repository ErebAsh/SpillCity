import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spillcity/domain/entities/post.dart';

// Category color mappings from CSS theme
final Map<String, Color> categoryColors = {
  'Events': const Color(0xFF7C3AED),
  'Notices': const Color(0xFFF59E0B),
  'Sports': const Color(0xFF10B981),
  'Academic': const Color(0xFF3B82F6),
  'Clubs': const Color(0xFFEC4899),
  'Exams': const Color(0xFFF43F5E),
  'News': const Color(0xFF6366F1),
  'College Daily Update': const Color(0xFF14B8A6),
  'Others': const Color(0xFF94A3B8),
};

// Category emojis mapping
final Map<String, String> categoryEmojis = {
  'Events': '🎉',
  'Notices': '📢',
  'Sports': '⚽',
  'Academic': '📚',
  'Clubs': '🎭',
  'Exams': '📝',
  'News': '📰',
  'College Daily Update': '🗓️',
  'Others': '✨',
};

class PostCard extends StatefulWidget {
  final PostModel post;
  final bool isHero;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onSaveToggle;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    this.isHero = false,
    this.onLikeToggle,
    this.onSaveToggle,
    this.onTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool isLiked;
  late bool isSaved;
  late int likesCount;

  @override
  void initState() {
    super.initState();
    isLiked = widget.post.isLiked;
    isSaved = widget.post.isSaved;
    likesCount = widget.post.likes;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHero) {
      return _buildHeroCard(context);
    }
    return _buildCompactCard(context);
  }

  // 1. HERO VARIANT (Full cover style)
  Widget _buildHeroCard(BuildContext context) {
    final categoryColor = categoryColors[widget.post.category] ?? const Color(0xFF6366F1);
    final categoryEmoji = categoryEmojis[widget.post.category] ?? '✨';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media Image
              CachedNetworkImage(
                imageUrl: widget.post.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[900]),
                errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
              ),
              // Dark Gradient Overlay for text readability
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black38,
                      Colors.black26,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
              // Card Details
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$categoryEmoji ${widget.post.category ?? "Others"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      widget.post.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Description
                    Text(
                      widget.post.description,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Author Metadata Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: () {
                            final avatarUrl = widget.post.authorAvatar ?? '';
                            if (avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com')) {
                              return NetworkImage(avatarUrl);
                            }
                            return null;
                          }(),
                          child: () {
                            final avatarUrl = widget.post.authorAvatar ?? '';
                            if (avatarUrl.isEmpty || !avatarUrl.startsWith('http') || avatarUrl.contains('ui-avatars.com')) {
                              return Text(
                                avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                                    ? avatarUrl
                                    : (widget.post.authorName?.isNotEmpty == true ? widget.post.authorName![0].toUpperCase() : 'U'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              );
                            }
                            return null;
                          }(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.post.authorName ?? "User"} • ${widget.post.publishedAt}', // Simplifies timeAgo
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Floating Top Actions (Like & Bookmark)
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    _buildGlassIconButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                      onPressed: () {
                        setState(() {
                          isLiked = !isLiked;
                          likesCount = isLiked ? likesCount + 1 : likesCount - 1;
                        });
                        widget.onLikeToggle?.call();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildGlassIconButton(
                      icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? Colors.blue : Colors.white,
                      onPressed: () {
                        setState(() {
                          isSaved = !isSaved;
                        });
                        widget.onSaveToggle?.call();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper builder for Hero's frosted-glass button style
  Widget _buildGlassIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, size: 18, color: color),
        onPressed: onPressed,
      ),
    );
  }

  // 2. COMPACT VARIANT (Horizontal Row style)
  Widget _buildCompactCard(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = categoryColors[widget.post.category] ?? const Color(0xFF6366F1);
    final categoryEmoji = categoryEmojis[widget.post.category] ?? '✨';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Text Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Category + TimeAgo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$categoryEmoji ${widget.post.category ?? "Others"}',
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '•',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Just now', // Replace with real timeAgo calculations in helper
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title
                  InkWell(
                    onTap: widget.onTap,
                    child: Text(
                      widget.post.title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    widget.post.description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Action Row (Author Info, Likes count, Save button)
                  Row(
                    children: [
                      // Author Avatar
                      CircleAvatar(
                        radius: 11,
                        backgroundImage: () {
                          final avatarUrl = widget.post.authorAvatar ?? '';
                          if (avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com')) {
                            return NetworkImage(avatarUrl);
                          }
                          return null;
                        }(),
                        child: () {
                          final avatarUrl = widget.post.authorAvatar ?? '';
                          if (avatarUrl.isEmpty || !avatarUrl.startsWith('http') || avatarUrl.contains('ui-avatars.com')) {
                            return Text(
                              avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                                  ? avatarUrl
                                  : (widget.post.authorName?.isNotEmpty == true ? widget.post.authorName![0].toUpperCase() : 'U'),
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                            );
                          }
                          return null;
                        }(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.post.authorName ?? "User",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // Like Action
                      _buildActionBtn(
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        label: likesCount > 0 ? '$likesCount' : null,
                        onPressed: () {
                          setState(() {
                            isLiked = !isLiked;
                            likesCount = isLiked ? likesCount + 1 : likesCount - 1;
                          });
                          widget.onLikeToggle?.call();
                        },
                      ),
                      // Save Action
                      _buildActionBtn(
                        icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved ? Colors.blue : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        onPressed: () {
                          setState(() {
                            isSaved = !isSaved;
                          });
                          widget.onSaveToggle?.call();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right Thumbnail Image (if image URL is present)
            if (widget.post.imageUrl.isNotEmpty) ...[
              const SizedBox(width: 12),
              InkWell(
                onTap: widget.onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.post.imageUrl,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(color: Colors.grey[200]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Builder for compact button icons
  Widget _buildActionBtn({
    required IconData icon,
    required Color color,
    String? label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
