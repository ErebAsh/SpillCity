import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/domain/entities/user.dart';
import 'package:spillcity/domain/entities/post.dart';
import 'package:spillcity/presentation/settings/screens/settings_screen.dart';

// ── Category colors matching TypeScript ──
const Map<String, Color> _categoryColors = {
  'Events': Color(0xFF8B5CF6),
  'Notices': Color(0xFFF59E0B),
  'Sports': Color(0xFF10B981),
  'Academic': Color(0xFF2563EB),
  'Clubs': Color(0xFFEC4899),
  'Exams': Color(0xFFEF4444),
  'News': Color(0xFF6366F1),
  'College Daily Update': Color(0xFF14B8A6),
  'Others': Color(0xFF94A3B8),
};

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // Null means current logged-in user

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = true;
  UserModel? _profileUser;
  List<PostModel> _userPosts = [];
  List<PostModel> _savedPosts = [];
  bool _isFollowing = false;
  bool _isMe = true;
  String? _errorMsg;
  String _activeTab = 'posts'; // 'posts' | 'saved'

  // Lightbox state
  bool _showFullImage = false;

  // Follow modal
  bool _showFollowModal = false;
  String _followModalType = 'followers';
  List<Map<String, dynamic>> _followList = [];
  bool _isFollowListLoading = false;
  Set<String> _myFollowingIds = {};

  // Unfollow confirmation
  Map<String, dynamic>? _userToUnfollow;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final postRepo = ref.read(postRepositoryProvider);
      final currentUserId = authRepo.currentSupabaseUser?.id;

      if (widget.userId == null || widget.userId == currentUserId) {
        _isMe = true;
        final selfProfile = await authRepo.getCurrentUserProfile();
        if (selfProfile != null) {
          _profileUser = selfProfile;
          final results = await Future.wait([
            postRepo.getUserPosts(selfProfile.id),
            postRepo.getSavedPosts(selfProfile.id),
          ]);
          _userPosts = results[0];
          _savedPosts = results[1];
        } else {
          _errorMsg = "Unable to load current user profile.";
        }
      } else {
        _isMe = false;
        final targetId = widget.userId!;
        final targetProfile = await authRepo.getUserProfile(targetId);
        if (targetProfile != null) {
          _profileUser = targetProfile;

          final results = await Future.wait([
            postRepo.getUserPosts(targetId),
            currentUserId != null
                ? authRepo.isFollowingUser(currentUserId, targetId)
                : Future.value(false),
          ]);
          _userPosts = results[0] as List<PostModel>;
          _isFollowing = results[1] as bool;
        } else {
          _errorMsg = "User profile not found.";
        }
      }
    } catch (e) {
      _errorMsg = "Error loading profile: $e";
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_profileUser == null || _isMe) return;
    final authRepo = ref.read(authRepositoryProvider);
    final currentUserId = authRepo.currentSupabaseUser?.id;
    if (currentUserId == null) return;

    // If already following, show unfollow confirmation
    if (_isFollowing) {
      setState(() {
        _userToUnfollow = {
          'id': _profileUser!.id,
          'name': _profileUser!.name,
          'avatar': _profileUser!.avatar,
          'isList': false,
        };
      });
      return;
    }

    final previousState = _isFollowing;
    setState(() {
      _isFollowing = true;
      if (_profileUser != null) {
        _profileUser = UserModel(
          id: _profileUser!.id,
          name: _profileUser!.name,
          username: _profileUser!.username,
          email: _profileUser!.email,
          avatar: _profileUser!.avatar,
          localAvatar: _profileUser!.localAvatar,
          college: _profileUser!.college,
          bio: _profileUser!.bio,
          followers: _profileUser!.followers + 1,
          following: _profileUser!.following,
          postsCount: _profileUser!.postsCount,
          onboardingComplete: _profileUser!.onboardingComplete,
        );
      }
    });

    try {
      final successState = await authRepo.toggleFollowUser(
        currentUserId,
        _profileUser!.id,
        previousState,
      );
      if (successState != _isFollowing) {
        setState(() {
          _isFollowing = successState;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFollowing = previousState;
        if (_profileUser != null) {
          _profileUser = UserModel(
            id: _profileUser!.id,
            name: _profileUser!.name,
            username: _profileUser!.username,
            email: _profileUser!.email,
            avatar: _profileUser!.avatar,
            localAvatar: _profileUser!.localAvatar,
            college: _profileUser!.college,
            bio: _profileUser!.bio,
            followers: _profileUser!.followers - 1,
            following: _profileUser!.following,
            postsCount: _profileUser!.postsCount,
            onboardingComplete: _profileUser!.onboardingComplete,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update follow status')),
      );
    }
  }

  Future<void> _confirmUnfollow() async {
    if (_userToUnfollow == null) return;
    final targetId = _userToUnfollow!['id'] as String;
    final isList = _userToUnfollow!['isList'] as bool;
    setState(() => _userToUnfollow = null);

    final authRepo = ref.read(authRepositoryProvider);
    final currentUserId = authRepo.currentSupabaseUser?.id;
    if (currentUserId == null) return;

    if (isList) {
      final previousFollowingIds = Set<String>.from(_myFollowingIds);
      final previousFollowList = List<Map<String, dynamic>>.from(_followList);
      final previousProfileUser = _profileUser;

      setState(() {
        _myFollowingIds = Set<String>.from(_myFollowingIds)..remove(targetId);
        if (_isMe) {
          if (_profileUser != null) {
            _profileUser = UserModel(
              id: _profileUser!.id,
              name: _profileUser!.name,
              username: _profileUser!.username,
              email: _profileUser!.email,
              avatar: _profileUser!.avatar,
              localAvatar: _profileUser!.localAvatar,
              college: _profileUser!.college,
              bio: _profileUser!.bio,
              followers: _profileUser!.followers,
              following: _profileUser!.following - 1,
              postsCount: _profileUser!.postsCount,
              onboardingComplete: _profileUser!.onboardingComplete,
            );
          }
          if (_followModalType == 'following') {
            _followList = _followList.where((u) => u['id'] != targetId).toList();
          }
        }
      });
      try {
        final successState = await authRepo.toggleFollowUser(currentUserId, targetId, true);
        if (successState) {
          throw Exception("Unfollow failed");
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _myFollowingIds = previousFollowingIds;
          _followList = previousFollowList;
          _profileUser = previousProfileUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed')),
        );
      }
    } else {
      setState(() {
        _isFollowing = false;
        if (_profileUser != null) {
          _profileUser = UserModel(
            id: _profileUser!.id,
            name: _profileUser!.name,
            username: _profileUser!.username,
            email: _profileUser!.email,
            avatar: _profileUser!.avatar,
            localAvatar: _profileUser!.localAvatar,
            college: _profileUser!.college,
            bio: _profileUser!.bio,
            followers: _profileUser!.followers - 1,
            following: _profileUser!.following,
            postsCount: _profileUser!.postsCount,
            onboardingComplete: _profileUser!.onboardingComplete,
          );
        }
      });
      try {
        await authRepo.toggleFollowUser(currentUserId, targetId, true);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isFollowing = true;
          if (_profileUser != null) {
            _profileUser = UserModel(
              id: _profileUser!.id,
              name: _profileUser!.name,
              username: _profileUser!.username,
              email: _profileUser!.email,
              avatar: _profileUser!.avatar,
              localAvatar: _profileUser!.localAvatar,
              college: _profileUser!.college,
              bio: _profileUser!.bio,
              followers: _profileUser!.followers + 1,
              following: _profileUser!.following,
              postsCount: _profileUser!.postsCount,
              onboardingComplete: _profileUser!.onboardingComplete,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update follow status')),
        );
      }
    }
  }

  Future<void> _openFollowModal(String type) async {
    if (_profileUser == null) return;
    setState(() {
      _showFollowModal = true;
      _followModalType = type;
      _followList = [];
      _isFollowListLoading = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final currentUserId = authRepo.currentSupabaseUser?.id;

      final results = await Future.wait([
        type == 'followers'
            ? authRepo.getFollowers(_profileUser!.id)
            : authRepo.getFollowing(_profileUser!.id),
        currentUserId != null
            ? authRepo.getFollowing(currentUserId)
            : Future.value(<Map<String, dynamic>>[]),
      ]);

      final fetchedList = results[0];
      final myFollowingList = results[1];

      if (mounted) {
        setState(() {
          _followList = fetchedList;
          _myFollowingIds = myFollowingList
              .map((u) => u['id'] as String? ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
          _isFollowListLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowListLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load list: $e')),
        );
      }
    }
  }

  Future<void> _handleListFollowToggle(Map<String, dynamic> targetUser) async {
    final authRepo = ref.read(authRepositoryProvider);
    final currentUserId = authRepo.currentSupabaseUser?.id;
    if (currentUserId == null || targetUser['id'] == null) return;
    
    final targetId = targetUser['id'] as String;
    if (targetId == currentUserId) return;

    final isCurrentlyFollowing = _myFollowingIds.contains(targetId);
    if (isCurrentlyFollowing) {
      setState(() {
        _userToUnfollow = {
          'id': targetId,
          'name': targetUser['name'] ?? 'User',
          'avatar': targetUser['profile_picture'] ?? targetUser['profilePicture'] ?? targetUser['avatar'] ?? '',
          'isList': true,
        };
      });
      return;
    }

    final previousFollowingIds = Set<String>.from(_myFollowingIds);
    setState(() {
      _myFollowingIds.add(targetId);
      if (_isMe && _profileUser != null) {
        _profileUser = UserModel(
          id: _profileUser!.id,
          name: _profileUser!.name,
          username: _profileUser!.username,
          email: _profileUser!.email,
          avatar: _profileUser!.avatar,
          localAvatar: _profileUser!.localAvatar,
          college: _profileUser!.college,
          bio: _profileUser!.bio,
          followers: _profileUser!.followers,
          following: _profileUser!.following + 1,
          postsCount: _profileUser!.postsCount,
          onboardingComplete: _profileUser!.onboardingComplete,
        );
      }
    });

    try {
      final successState = await authRepo.toggleFollowUser(currentUserId, targetId, false);
      if (!successState) {
        throw Exception("Follow failed");
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myFollowingIds = previousFollowingIds;
        if (_isMe && _profileUser != null) {
          _profileUser = UserModel(
            id: _profileUser!.id,
            name: _profileUser!.name,
            username: _profileUser!.username,
            email: _profileUser!.email,
            avatar: _profileUser!.avatar,
            localAvatar: _profileUser!.localAvatar,
            college: _profileUser!.college,
            bio: _profileUser!.bio,
            followers: _profileUser!.followers,
            following: _profileUser!.following - 1,
            postsCount: _profileUser!.postsCount,
            onboardingComplete: _profileUser!.onboardingComplete,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed')),
      );
    }
  }

  void _showOptionsSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _buildOptionTile(ctx, '🔗', 'Copy Link', () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: 'https://proxypress.app/profile/${_profileUser?.id ?? ''}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile link copied!')),
                );
              }),
              _buildOptionTile(ctx, '📤', 'Share Profile', () {
                Navigator.pop(ctx);
              }),
              if (!_isMe) ...[
                _buildOptionTile(ctx, '🔕', 'Mute', () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_profileUser?.name ?? 'User'} muted')),
                  );
                }),
                _buildOptionTile(ctx, '🚫', 'Block', () {
                  Navigator.pop(ctx);
                  _showBlockConfirmDialog();
                }, isDanger: true),
                _buildOptionTile(ctx, '🚩', 'Report', () {
                  Navigator.pop(ctx);
                  _showReportDialog();
                }, isDanger: true),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(BuildContext ctx, String emoji, String label, VoidCallback onTap, {bool isDanger = false}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDanger ? const Color(0xFFEF4444) : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Text(
                    'Block ${_profileUser?.name ?? 'User'}?',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "They won't be able to find your profile, posts or story on ProxyPress.",
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${_profileUser?.name ?? 'User'} blocked')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Block', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    final theme = Theme.of(context);
    const reasons = [
      'Spam or misleading',
      'Harassment or bullying',
      'Inappropriate content',
      'Impersonation',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Why are you reporting this account?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                ),
              ),
            ),
            ...reasons.map((reason) => Column(
              children: [
                Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted. We will review it shortly.')),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(reason, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                    ),
                  ),
                ),
              ],
            )),
            Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAvatarUrl(UserModel user) {
    return user.resolvedAvatarUrl;
  }

  Widget _buildAvatarImage(UserModel user, double size, ThemeData theme) {
    final avatarUrl = _getAvatarUrl(user);

    Widget imageWidget;
    if (avatarUrl.isEmpty || avatarUrl.contains('ui-avatars.com')) {
      imageWidget = _buildFallbackAvatar(user, size, theme);
    } else if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      imageWidget = Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackAvatar(user, size, theme),
      );
    } else {
      final file = File(avatarUrl);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackAvatar(user, size, theme),
        );
      } else {
        imageWidget = _buildFallbackAvatar(user, size, theme);
      }
    }

    return ClipOval(child: imageWidget);
  }

  Widget _buildFallbackAvatar(UserModel user, double size, ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(child: _buildSkeleton(theme)),
      );
    }

    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(_errorMsg!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadProfileData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _profileUser!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadProfileData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                child: Column(
                  children: [
                    // ── Header: Back ← Avatar → Settings/Options ──
                    _buildHeaderSection(theme, user),

                    // ── Bio Section (centered) ──
                    _buildBioSection(theme, user),

                    // ── Stats Bar ──
                    _buildStatsBar(theme, user),

                    // ── Action Buttons ──
                    _buildActionButtons(theme, user),

                    // ── Tabs ──
                    _buildTabs(theme),

                    // ── Post Grid ──
                    _buildPostGrid(theme),

                    // Extra bottom spacing
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),

          // ── Full Image Lightbox Overlay ──
          if (_showFullImage)
            _buildFullImageOverlay(theme, user),

          // ── Follow Modal Overlay ──
          if (_showFollowModal)
            _buildFollowModalOverlay(theme),

          // ── Unfollow Confirmation Overlay ──
          if (_userToUnfollow != null)
            _buildUnfollowConfirmOverlay(theme),
        ],
      ),
    );
  }

  // ─── Skeleton Loading ───
  Widget _buildSkeleton(ThemeData theme) {
    final shimmerBase = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Avatar skeleton
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(shape: BoxShape.circle, color: shimmerBase),
          ),
          const SizedBox(height: 16),
          // Name skeleton
          Container(width: 140, height: 20, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: shimmerBase)),
          const SizedBox(height: 8),
          Container(width: 90, height: 14, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: shimmerBase)),
          const SizedBox(height: 20),
          // Stats skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (_) => Container(
              width: 60, height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: shimmerBase),
            )),
          ),
          const SizedBox(height: 20),
          // Grid skeleton
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: List.generate(6, (_) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: shimmerBase,
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header: back button ← jumbo avatar → settings/options ───
  Widget _buildHeaderSection(ThemeData theme, UserModel user) {
    return Column(
      children: [
        // Top Action Bar containing Back Button (left) and Settings/Options (right)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    icon: Icon(Icons.chevron_left, size: 28, color: theme.colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  const SizedBox(width: 48),
                const Spacer(),
                _isMe
                    ? IconButton(
                        icon: Icon(Icons.settings_outlined, size: 24, color: theme.colorScheme.onSurface),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                          if (result == true) _loadProfileData();
                        },
                      )
                    : IconButton(
                        icon: Icon(Icons.more_vert, size: 24, color: theme.colorScheme.onSurface),
                        onPressed: _showOptionsSheet,
                      ),
              ],
            ),
          ),
        ),

        // Center: Avatar with gradient ring
        GestureDetector(
          onTap: () => setState(() => _showFullImage = true),
          child: Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), Color(0xFF515BD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 3),
              ),
              child: _buildAvatarImage(user, 92, theme),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ─── Bio Section (centered, matching .ig-profile-bio-modern) ───
  Widget _buildBioSection(ThemeData theme, UserModel user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          // Name (h1)
          Text(
            user.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          // @username (primary color)
          if (user.username != null && user.username!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '@${user.username}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                  letterSpacing: -0.01,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          // College tag
          if (user.college != null && user.college!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                user.college!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          // Bio text
          if (user.bio != null && user.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                user.bio!,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // ─── Stats Bar (Posts, Followers, Following) ───
  Widget _buildStatsBar(ThemeData theme, UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(theme, _userPosts.length.toString(), 'posts'),
          GestureDetector(
            onTap: () => _openFollowModal('followers'),
            child: _buildStat(theme, user.followers.toString(), 'followers', isClickable: true),
          ),
          GestureDetector(
            onTap: () => _openFollowModal('following'),
            child: _buildStat(theme, user.following.toString(), 'following', isClickable: true),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(ThemeData theme, String value, String label, {bool isClickable = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ─── Action Buttons ───
  Widget _buildActionButtons(ThemeData theme, UserModel user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          if (_isMe) ...[
            // Share Profile (full width for self)
            Expanded(
              child: _buildActionButton(
                label: 'Share Profile',
                onTap: _showOptionsSheet,
                isSecondary: true,
                theme: theme,
              ),
            ),
          ] else ...[
            // Follow / Following button
            Expanded(
              flex: 2,
              child: _isFollowing
                  ? _buildActionButton(
                      label: 'Following',
                      onTap: _handleFollowToggle,
                      isFollowing: true,
                      theme: theme,
                    )
                  : _buildActionButton(
                      label: 'Follow',
                      onTap: _handleFollowToggle,
                      isFollow: true,
                      theme: theme,
                    ),
            ),
            const SizedBox(width: 6),
            // Message button
            Expanded(
              flex: 2,
              child: _buildActionButton(
                label: 'Message',
                onTap: () {
                  // Navigate to messages with this user
                },
                isMessage: true,
                theme: theme,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isFollow = false,
    bool isFollowing = false,
    bool isMessage = false,
    bool isSecondary = false,
  }) {
    Color bgColor;
    Color textColor;
    Border? border;

    if (isFollow) {
      bgColor = const Color(0xFF0095F6);
      textColor = Colors.white;
    } else if (isFollowing) {
      bgColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurface;
      border = Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2));
    } else if (isMessage) {
      bgColor = theme.brightness == Brightness.dark
          ? const Color(0xFF333333)
          : const Color(0xFF1A1A1A);
      textColor = Colors.white;
    } else {
      bgColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurface;
      border = Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2));
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
          gradient: isFollow
              ? const LinearGradient(colors: [Color(0xFF0095F6), Color(0xFF0078D4)])
              : isMessage
                  ? LinearGradient(colors: [
                      theme.brightness == Brightness.dark ? const Color(0xFF333333) : const Color(0xFF222222),
                      Colors.black,
                    ])
                  : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ─── Tabs (Posts grid icon / Saved bookmark icon) ───
  Widget _buildTabs(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 'posts'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 'posts' ? theme.colorScheme.onSurface : Colors.transparent,
                      width: 1,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _activeTab == 'posts' ? Icons.grid_view : Icons.grid_view_outlined,
                  size: 22,
                  color: _activeTab == 'posts'
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          if (_isMe)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 'saved'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _activeTab == 'saved' ? theme.colorScheme.onSurface : Colors.transparent,
                        width: 1,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _activeTab == 'saved' ? Icons.bookmark : Icons.bookmark_border,
                    size: 22,
                    color: _activeTab == 'saved'
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Post Grid (2 columns, rounded, overlay with category/title/stats) ───
  Widget _buildPostGrid(ThemeData theme) {
    final displayPosts = _activeTab == 'posts' ? _userPosts : (_isMe ? _savedPosts : []);

    if (displayPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.onSurface, width: 2),
              ),
              child: Icon(
                _activeTab == 'saved' ? Icons.bookmark_border : Icons.camera_alt_outlined,
                size: 28,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _activeTab == 'saved' ? 'No Saved Posts' : 'No Posts Yet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _activeTab == 'saved'
                  ? 'Posts you save will appear here.'
                  : _isMe
                      ? 'Share your first post with the community.'
                      : 'This user hasn\'t posted yet.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: displayPosts.length,
        itemBuilder: (context, index) {
          final post = displayPosts[index];
          return _buildGridItem(theme, post, index);
        },
      ),
    );
  }

  Widget _buildGridItem(ThemeData theme, PostModel post, int index) {
    final categoryColor = _categoryColors[post.category] ?? const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () {
        if (post.slug.isNotEmpty) {
          context.push('/article/${post.slug}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (post.imageUrl.isNotEmpty)
              Image.network(
                post.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildTextPostGrid(theme, post),
              )
            else
              _buildTextPostGrid(theme, post),

            // Gradient overlay (matching .ig-grid-overlay-premium)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Overlay content (category badge, title, stats)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  if (post.category != null && post.category!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.category!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Title
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Stats row (likes + comments)
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likes}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${post.comments}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
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

  Widget _buildTextPostGrid(ThemeData theme, PostModel post) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        post.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  // ─── Full Image Lightbox (matching .ig-full-image-overlay) ───
  Widget _buildFullImageOverlay(ThemeData theme, UserModel user) {
    return GestureDetector(
      onTap: () => setState(() => _showFullImage = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {}, // prevent closing when tapping image
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 50,
                ),
              ],
            ),
            child: _buildAvatarImage(user, 500, theme),
          ),
        ),
      ),
    );
  }

  // ─── Follow Modal (Followers / Following list) ───
  Widget _buildFollowModalOverlay(ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _showFollowModal = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        _followModalType == 'followers' ? 'Followers' : 'Following',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                      ),
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _showFollowModal = false),
                          child: Text('✕', style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface)),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),

                // Content
                if (_isFollowListLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  )
                else if (_followList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'No $_followModalType yet.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _followList.length,
                      itemBuilder: (context, index) {
                        final item = _followList[index];
                        return _buildFollowListItem(theme, item);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowListItem(ThemeData theme, Map<String, dynamic> item) {
    final authRepo = ref.read(authRepositoryProvider);
    final currentUserId = authRepo.currentSupabaseUser?.id;
    final targetId = item['id'] as String? ?? '';
    final isFollowing = _myFollowingIds.contains(targetId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              if (targetId.isNotEmpty) {
                setState(() => _showFollowModal = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen(userId: targetId)),
                );
              }
            },
            child: Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), Color(0xFF515BD4)],
                ),
              ),
              child: ClipOval(
                child: Container(
                  color: theme.colorScheme.surface,
                  alignment: Alignment.center,
                  child: () {
                    final avatarUrl = () {
                      if (item['profile_picture'] != null && (item['profile_picture'] as String).isNotEmpty) {
                        return item['profile_picture'] as String;
                      }
                      if (item['profilePicture'] != null && (item['profilePicture'] as String).isNotEmpty) {
                        return item['profilePicture'] as String;
                      }
                      if (item['avatar'] != null && (item['avatar'] as String).isNotEmpty) {
                        return item['avatar'] as String;
                      }
                      if (item['image'] != null && (item['image'] as String).isNotEmpty) {
                        return item['image'] as String;
                      }
                      return '';
                    }();
                    if (avatarUrl.isNotEmpty) {
                      return Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (_, _, _) => Text(
                          (item['name'] as String? ?? '?')[0].toUpperCase(),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      );
                    } else {
                      return Text(
                        (item['name'] as String? ?? '?')[0].toUpperCase(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      );
                    }
                  }(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + username
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (targetId.isNotEmpty) {
                  setState(() => _showFollowModal = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen(userId: targetId)),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? '',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: theme.colorScheme.onSurface),
                  ),
                  Text(
                    '@${item['username'] ?? (item['name'] ?? '').toLowerCase().replaceAll(' ', '')}',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),
          // Follow button
          if (currentUserId != null && targetId.isNotEmpty && targetId != currentUserId)
            GestureDetector(
              onTap: () => _handleListFollowToggle(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isFollowing ? theme.colorScheme.surfaceContainerHighest : const Color(0xFF0095F6),
                  borderRadius: BorderRadius.circular(8),
                  border: isFollowing ? Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)) : null,
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isFollowing ? theme.colorScheme.onSurface : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Unfollow Confirmation Dialog ───
  Widget _buildUnfollowConfirmOverlay(ThemeData theme) {
    final target = _userToUnfollow!;

    return GestureDetector(
      onTap: () => setState(() => _userToUnfollow = null),
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 90,
                        height: 90,
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF), Color(0xFF515BD4)],
                          ),
                        ),
                        child: ClipOval(
                          child: Container(
                            color: theme.colorScheme.surface,
                            alignment: Alignment.center,
                            child: () {
                              final avatarUrl = () {
                                if (target['profile_picture'] != null && (target['profile_picture'] as String).isNotEmpty) {
                                  return target['profile_picture'] as String;
                                }
                                if (target['profilePicture'] != null && (target['profilePicture'] as String).isNotEmpty) {
                                  return target['profilePicture'] as String;
                                }
                                if (target['avatar'] != null && (target['avatar'] as String).isNotEmpty) {
                                  return target['avatar'] as String;
                                }
                                if (target['image'] != null && (target['image'] as String).isNotEmpty) {
                                  return target['image'] as String;
                                }
                                return '';
                              }();
                              if (avatarUrl.isNotEmpty) {
                                return Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  width: 84,
                                  height: 84,
                                  errorBuilder: (_, _, _) => Text(
                                    ((target['name'] as String?) ?? '?')[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                                  ),
                                );
                              } else {
                                return Text(
                                  ((target['name'] as String?) ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                                );
                              }
                            }(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unfollow @${(target['name'] as String? ?? '').toLowerCase().replaceAll(' ', '')}?',
                        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                // Unfollow action
                InkWell(
                  onTap: _confirmUnfollow,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Unfollow',
                        style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                // Cancel
                InkWell(
                  onTap: () => setState(() => _userToUnfollow = null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
