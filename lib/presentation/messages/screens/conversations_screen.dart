import '../../feed/screens/story_viewer_overlay.dart';
import '../../feed/screens/story_creation_sheet.dart';
import 'chat_screen.dart';
import 'package:spillcity/core/utils/helpers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/domain/entities/user.dart';
import 'package:spillcity/domain/entities/story.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/services/preferences_service.dart';

// ─── Format Time Utility ───
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  bool _isLoadingThreads = true;
  List<Map<String, dynamic>> _threads = [];
  List<StoryModel> _stories = [];
  List<StorySlideModel> _myStories = [];
  String? _activeConversationId;
  Map<String, dynamic>? _activeThreadDetails;
  String _searchQuery = '';
  List<UserModel> _globalSearchResults = [];
  Timer? _searchDebounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadStories();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    Future.microtask(() {
      try {
        ref.read(activeConversationIdProvider.notifier).state = null;
      } catch (_) {}
    });
    super.dispose();
  }

  Future<void> _loadStories() async {
    try {
      final supabase = Supabase.instance.client;
      final myId = supabase.auth.currentUser?.id;
      if (myId == null) return;

      final now = DateTime.now().toUtc();

      final response = await supabase
          .from('stories')
          .select('user_id, seen, user:users(id, name, username, avatar, profile_picture), slides:story_slides(*), views:story_views(*)');

      if (mounted) {
        final List<dynamic> list = response as List<dynamic>;
        final List<StoryModel> mappedStories = [];
        List<StorySlideModel> mappedMyStories = [];

        for (final item in list) {
          final userId = item['user_id'] as String;
          final userMap = item['user'] as Map<String, dynamic>? ?? {};
          final slidesList = item['slides'] as List<dynamic>? ?? [];
          final viewsList = item['views'] as List<dynamic>? ?? [];

          final activeSlides = slidesList
              .map((e) => StorySlideModel.fromJson(e as Map<String, dynamic>))
              .where((s) {
                final slideTime = DateTime.tryParse(s.createdAt) ?? DateTime.tryParse(s.timestamp) ?? DateTime.now();
                return now.difference(slideTime).inHours < 24;
              })
              .toList();

          if (activeSlides.isEmpty) continue;

          final hasSeen = viewsList.any((v) => v['viewer_id'] == myId);

          final story = StoryModel(
            userId: userId,
            authorName: userMap['name'] as String? ?? 'User',
            authorAvatar: userMap['profile_picture'] as String? ?? userMap['avatar'] as String? ?? '',
            seen: hasSeen,
            slides: activeSlides,
          );

          if (userId == myId) {
            mappedMyStories = activeSlides;
          } else {
            mappedStories.add(story);
          }
        }

        setState(() {
          _stories = mappedStories;
          _myStories = mappedMyStories;
        });
      }
    } catch (e) {
      debugPrint("Failed to load stories: $e");
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoadingThreads = true;
    });

    try {
      final supabaseClient = Supabase.instance.client;
      final currentUserId = supabaseClient.auth.currentUser?.id;

      if (currentUserId == null) return;

      final myParticipantsResponse = await supabaseClient
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', currentUserId);

      final List<dynamic> myParticipants = myParticipantsResponse as List<dynamic>? ?? [];
      final List<String> myConvIds = myParticipants.map((item) => item['conversation_id'] as String).toList();

      if (myConvIds.isEmpty) {
        setState(() {
          _threads = [];
          _isLoadingThreads = false;
        });
        return;
      }

      // Fetch unread counts per conversation
      final unreadResponse = await supabaseClient
          .from('messages')
          .select('conversation_id, seen')
          .inFilter('conversation_id', myConvIds)
          .neq('sender_id', currentUserId)
          .eq('seen', false);
      final List<dynamic> unreadMsgs = unreadResponse as List<dynamic>? ?? [];
      final Map<String, int> unreadCounts = {};
      for (final msg in unreadMsgs) {
        final cid = msg['conversation_id'] as String;
        unreadCounts[cid] = (unreadCounts[cid] ?? 0) + 1;
      }

      final threadsResponse = await supabaseClient
          .from('conversation_participants')
          .select('conversation_id, conversation:conversations(id, last_message, last_message_time, muted, vanish_mode), user:users(id, name, username, avatar, profile_picture)')
          .inFilter('conversation_id', myConvIds)
          .neq('user_id', currentUserId);

      final List<dynamic> threadsData = threadsResponse as List<dynamic>? ?? [];
      setState(() {
        _threads = threadsData.map((item) {
          final conv = item['conversation'] as Map<String, dynamic>? ?? {};
          final otherUser = item['user'] as Map<String, dynamic>? ?? {};
          final convId = item['conversation_id'] as String;

          return {
            'conversationId': convId,
            'lastMessage': conv['last_message'] as String? ?? '',
            'lastMessageTime': conv['last_message_time'] as String? ?? '',
            'muted': conv['muted'] as bool? ?? false,
            'vanishMode': conv['vanish_mode'] as bool? ?? false,
            'unreadCount': unreadCounts[convId] ?? 0,
            'otherUser': UserModel.fromJson(otherUser),
          };
        }).toList();

        // Sort: drafts first → unread → most recent
        _threads.sort((a, b) {
          final aNew = (a['conversationId'] as String).startsWith('new_');
          final bNew = (b['conversationId'] as String).startsWith('new_');
          if (aNew != bNew) return aNew ? -1 : 1;

          final aUnread = a['unreadCount'] as int;
          final bUnread = b['unreadCount'] as int;
          if (aUnread != bUnread) return bUnread.compareTo(aUnread);

          return (b['lastMessageTime'] as String).compareTo(a['lastMessageTime'] as String);
        });
      });
    } catch (e) {
      debugPrint("Failed to load conversations: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingThreads = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _searchDebounce?.cancel();
    if (query.trim().length > 1) {
      _searchDebounce = Timer(const Duration(milliseconds: 300), () => _globalSearch(query));
    } else {
      setState(() => _globalSearchResults = []);
    }
  }

  Future<void> _globalSearch(String query) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;
      final existingUserIds = _threads.map((t) => (t['otherUser'] as UserModel).id).toSet();

      var qb = supabase
          .from('users')
          .select('id, name, username, avatar, profile_picture')
          .or('name.ilike.%$query%,username.ilike.%$query%');

      if (currentUserId != null) {
        qb = qb.neq('id', currentUserId);
      }

      final res = await qb.limit(10);
      if (mounted) {
        final List<dynamic> list = res as List<dynamic>;
        setState(() {
          _globalSearchResults = list
              .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
              .where((u) => !existingUserIds.contains(u.id))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Global search failed: $e");
    }
  }

  void _openChat(Map<String, dynamic> thread) {
    setState(() {
      _activeConversationId = thread['conversationId'];
      _activeThreadDetails = thread;
    });
    ref.read(activeConversationIdProvider.notifier).state = thread['conversationId'];
    if (thread['conversationId'] != null) {
      PreferencesService.instance.remove('unread_count_${thread['conversationId']}');
    }
  }

  void _closeChat() {
    setState(() {
      _activeConversationId = null;
      _activeThreadDetails = null;
    });
    ref.read(activeConversationIdProvider.notifier).state = null;
    _loadConversations();
    _loadStories();
  }

  void _startChatWithUser(UserModel user) {
    // Check if conversation already exists
    final existingThread = _threads.firstWhere(
      (t) => (t['otherUser'] as UserModel).id == user.id,
      orElse: () => <String, dynamic>{},
    );
    if (existingThread.isNotEmpty) {
      _openChat(existingThread);
      return;
    }

    final draftThread = {
      'conversationId': 'new_${user.id}',
      'lastMessage': '',
      'lastMessageTime': '',
      'muted': false,
      'vanishMode': false,
      'unreadCount': 0,
      'otherUser': user,
    };
    _openChat(draftThread);
  }



  void _showCreateStory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StoryCreationSheet(),
    ).then((success) {
      if (success == true) {
        _loadStories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story created successfully! ⚡')),
          );
        }
      }
    });
  }

  void _viewStory(int index, List<StoryModel> allStories) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, _) => StoryViewerOverlay(
          initialUserIndex: index,
          stories: allStories,
          onFinish: () => Navigator.of(context).pop(),
        ),
      ),
    ).then((_) {
      _loadStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_activeConversationId != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _closeChat();
        },
        child: ChatConversationPanel(
          conversationId: _activeConversationId!,
          threadDetails: _activeThreadDetails!,
          onBack: _closeChat,
        ),
      );
    }

    final filteredThreads = _threads.where((thread) {
      final otherUser = thread['otherUser'] as UserModel;
      final nameMatch = otherUser.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final usernameMatch = (otherUser.username ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      return nameMatch || usernameMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 14),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
              ),

              // Stories Horizontal List
              _buildStoriesTraySection(),

              const SizedBox(height: 8),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadConversations();
                    await _loadStories();
                  },
                  child: _isLoadingThreads
                      ? const Center(child: CircularProgressIndicator())
                      : (filteredThreads.isEmpty && _globalSearchResults.isEmpty)
                          ? _buildEmptyState()
                          : ListView(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              children: [
                                // Existing conversations
                                ...filteredThreads.map((thread) => _buildConversationTile(thread, theme)),

                                // Global search results
                                if (_globalSearchResults.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                    child: Text(
                                      'Other Users',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  ..._globalSearchResults.map((user) => _buildSearchResultTile(user, theme)),
                                ],
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> thread, ThemeData theme) {
    final otherUser = thread['otherUser'] as UserModel;
    final avatarUrl = otherUser.resolvedAvatarUrl;
    final hasAvatar = avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com');
    final timeStr = thread['lastMessageTime'] as String;
    final unreadCount = thread['unreadCount'] as int? ?? 0;
    final isMuted = thread['muted'] as bool? ?? false;
    final lastMessage = thread['lastMessage'] as String? ?? '';

    return InkWell(
      onTap: () => _openChat(thread),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with online dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                  child: !hasAvatar
                      ? Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                                ? avatarUrl
                                : (otherUser.name.isNotEmpty ? otherUser.name.substring(0, 1).toUpperCase() : '?'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          otherUser.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        formatMessageTime(timeStr),
                        style: TextStyle(
                          color: unreadCount > 0
                              ? const Color(0xFF2563EB)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          fontSize: 12,
                          fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isMuted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.volume_off,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                        ),
                      ],
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          height: 20,
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3B30), Color(0xFFFF2D55)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(UserModel user, ThemeData theme) {
    final avatarUrl = user.resolvedAvatarUrl;
    final hasAvatar = avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com');

    return InkWell(
      onTap: () {
        _startChatWithUser(user);
        setState(() {
          _searchQuery = '';
          _globalSearchResults = [];
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
              child: !hasAvatar
                  ? Text(
                      avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                          ? avatarUrl
                          : (user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?'),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (user.username != null)
                    Text(
                      '@${user.username}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesTraySection() {
    final theme = Theme.of(context);
    final hasMyStory = _myStories.isNotEmpty;
    final supabase = Supabase.instance.client;
    final myProfilePic = supabase.auth.currentUser?.userMetadata?['profile_picture'] as String?;

    final List<dynamic> trayList = [];
    trayList.add('me');
    trayList.addAll(_stories);

    return Container(
      height: 104,
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: trayList.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            final borderGradient = hasMyStory
                ? const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [theme.colorScheme.outline.withValues(alpha: 0.15), theme.colorScheme.outline.withValues(alpha: 0.15)],
                  );

            return GestureDetector(
              onTap: hasMyStory
                  ? () => _viewStory(0, [
                        StoryModel(
                          userId: supabase.auth.currentUser?.id ?? 'me',
                          authorName: 'Your Story',
                          authorAvatar: myProfilePic ?? '',
                          slides: _myStories,
                        )
                      ])
                  : _showCreateStory,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: borderGradient,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: hasMyStory
                                  ? Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        '✦',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : (myProfilePic != null && myProfilePic.isNotEmpty && !myProfilePic.contains('ui-avatars.com'))
                                      ? Image.network(
                                          myProfilePic,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                          child: Icon(
                                            Icons.person_outline,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                            size: 26,
                                          ),
                                        ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _showCreateStory,
                            child: Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your story',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final story = trayList[index] as StoryModel;
          final avatarUrl = story.authorAvatar;
          final hasAv = avatarUrl.isNotEmpty && !avatarUrl.contains('ui-avatars.com');
          final borderGradient = story.seen
              ? LinearGradient(colors: [theme.colorScheme.outline.withValues(alpha: 0.15), theme.colorScheme.outline.withValues(alpha: 0.15)])
              : const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                );

          return GestureDetector(
            onTap: () => _viewStory(index - 1, _stories),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: borderGradient,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: hasAv ? NetworkImage(avatarUrl) : null,
                        child: !hasAv
                            ? Text(
                                story.authorName.isNotEmpty ? story.authorName.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    story.authorName.split(' ')[0],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your Messages',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Send private messages to friends and classmates',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _searchFocusNode.requestFocus(),
                    borderRadius: BorderRadius.circular(24),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      child: Text(
                        'Send Message',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════
//  CHAT CONVERSATION PANEL — Full feature parity
// ════════════════════════════════════════════
