import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spillcity/data/repositories/providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref.read(notificationsProvider.future);
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(notificationsProvider);
    await _loadNotifications();
  }

  Future<void> _markRead(String notifId) async {
    await ref.read(authRepositoryProvider).markNotificationRead(notifId);
    ref.invalidate(unreadNotificationCountProvider);
    // Optimistic / Simple local update
    setState(() {
      _notifications = _notifications.map((n) {
        if (n['id'] == notifId) {
          return {...n, 'is_read': true};
        }
        return n;
      }).toList();
    });
  }

  Future<void> _markAllRead() async {
    await ref.read(authRepositoryProvider).markAllNotificationsRead();
    ref.invalidate(unreadNotificationCountProvider);
    setState(() {
      _notifications = _notifications.map((n) {
        return {...n, 'is_read': true};
      }).toList();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
    }
  }

  Future<void> _dismiss(String notifId) async {
    await ref.read(authRepositoryProvider).dismissNotification(notifId);
    ref.invalidate(unreadNotificationCountProvider);
    setState(() {
      _notifications.removeWhere((n) => n['id'] == notifId);
    });
  }

  Future<void> _respondFollow(String notifId, String actorId, bool accept) async {
    // Tries to find matching follow request details or constructs a request ID
    final requestId = notifId.replaceAll('ntf-frq-', '');
    try {
      await ref.read(authRepositoryProvider).respondToFollowRequest(requestId, actorId, accept);
      ref.invalidate(unreadNotificationCountProvider);
      setState(() {
        _notifications.removeWhere((n) => n['id'] == notifId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Follow request accepted' : 'Follow request deleted')),
      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: ${e.toString()}')),
      );
      }
    }
  }

  Widget _getNotifIcon(String type) {
    switch (type) {
      case 'like':
        return const Icon(Icons.favorite, color: Colors.red, size: 20);
      case 'comment':
        return const Icon(Icons.chat_bubble_outline, color: Colors.blue, size: 20);
      case 'mention':
        return const Icon(Icons.alternate_email, color: Colors.purple, size: 20);
      case 'alert':
        return const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20);
      case 'follow':
        return const Icon(Icons.person_outline, color: Colors.green, size: 20);
      case 'follow_request':
        return const Icon(Icons.person_add_alt_1_outlined, color: Colors.purple, size: 20);
      case 'follow_accept':
        return const Icon(Icons.check_circle_outline, color: Colors.teal, size: 20);
      case 'post':
        return const Icon(Icons.article_outlined, color: Colors.indigo, size: 20);
      default:
        return const Icon(Icons.notifications_none_outlined, size: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = _notifications.where((n) => !(n['is_read'] as bool? ?? false)).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark Read'),
              onPressed: _markAllRead,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          children: [
                            const Text('🔔', style: TextStyle(fontSize: 56)),
                            const SizedBox(height: 16),
                            const Text(
                              'No notifications',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "When someone likes or comments on your posts, you'll see it here.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] as bool? ?? false;
                      final type = n['type'] as String? ?? 'info';
                      final actor = n['actor'] as Map<String, dynamic>?;
                      final post = n['post'] as Map<String, dynamic>?;

                      return InkWell(
                        onTap: () {
                          _markRead(n['id'] as String);
                          if (n['post_id'] != null) {
                            // Find matching slug or just use ID if routes allow it, 
                            // we'll fetch details by slug/id in ArticleDetailScreen
                            context.push('/article/${n['post_id']}');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.transparent : theme.colorScheme.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon Stack with Badge
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: () {
                                      final avatarUrl = actor?['profile_picture'] as String? ?? actor?['avatar'] as String? ?? '';
                                      if (avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com')) {
                                        return NetworkImage(avatarUrl);
                                      }
                                      return null;
                                    }(),
                                    child: () {
                                      final avatarUrl = actor?['profile_picture'] as String? ?? actor?['avatar'] as String? ?? '';
                                      if (avatarUrl.isEmpty || !avatarUrl.startsWith('http') || avatarUrl.contains('ui-avatars.com')) {
                                        return Text(
                                          avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                                              ? avatarUrl
                                              : (actor?['name'] as String? ?? 'U')[0].toUpperCase(),
                                        );
                                      }
                                      return null;
                                    }(),
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: theme.colorScheme.surface, width: 2),
                                      ),
                                      child: _getNotifIcon(type),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              
                              // Content column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        text: '${actor?['name'] ?? 'Someone'} ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: n['message'] as String? ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.normal,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (post != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '"${post['title']}"',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      n['time_ago'] as String? ?? 'Recently',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ),

                                    // If follow request, display buttons
                                    if (type == 'follow_request') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _respondFollow(
                                              n['id'] as String,
                                              actor?['id'] as String? ?? '',
                                              true,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: const Text('Confirm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () => _respondFollow(
                                              n['id'] as String,
                                              actor?['id'] as String? ?? '',
                                              false,
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: const Text('Delete', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Unread indicator dot & dismiss button
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => _dismiss(n['id'] as String),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
