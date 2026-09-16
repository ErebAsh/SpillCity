import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:spillcity/data/repositories/providers.dart';
import 'package:spillcity/domain/entities/user.dart';
import 'package:spillcity/domain/entities/post.dart';
import 'package:spillcity/presentation/profile/screens/profile_screen.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = true;
  bool _isSearching = false;
  String _activeCategory = 'All';
  String _searchQuery = '';

  List<PostModel> _trendingPosts = [];
  List<UserModel> _suggestedUsers = [];
  
  List<UserModel> _searchResultsUsers = [];
  List<PostModel> _searchResultsPosts = [];
  Set<String> _myFollowingIds = {};

  final List<String> _categories = [
    'All', 'Events', 'Notices', 'Sports', 'Academic', 'Clubs', 'Exams', 'News', 'College Daily Update', 'Others'
  ];

  final Map<String, String> _categoryEmojis = {
    'All': '🌎', 'Events': '🎉', 'Notices': '📢', 'Sports': '⚽',
    'Academic': '📚', 'Clubs': '🎭', 'Exams': '📝', 'News': '📰',
    'College Daily Update': '🗓️', 'Others': '✨'
  };

  final Map<String, Color> _categoryColors = {
    'Events': const Color(0xFF8B5CF6),
    'Notices': const Color(0xFFF59E0B),
    'Sports': const Color(0xFF10B981),
    'Academic': const Color(0xFF2563EB),
    'Clubs': const Color(0xFFEC4899),
    'Exams': const Color(0xFFEF4444),
    'News': const Color(0xFF6366F1),
    'College Daily Update': const Color(0xFF14B8A6),
    'Others': const Color(0xFF94A3B8),
  };

  @override
  void initState() {
    super.initState();
    _loadInitialExploreData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialExploreData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabaseClient = Supabase.instance.client;
      final currentUserId = supabaseClient.auth.currentUser?.id;

      // 1. Fetch trending posts (order by likes/comments)
      final postsResponse = await supabaseClient
          .from('posts')
          .select('*, author:users(id, name, avatar, profile_picture)')
          .order('likes', ascending: false)
          .limit(15);

      final List<dynamic> postsData = postsResponse as List<dynamic>? ?? [];
      _trendingPosts = postsData.map((json) => PostModel.fromJson(json as Map<String, dynamic>)).toList();

      // 2. Fetch suggested users
      final usersResponse = await supabaseClient
          .from('users')
          .select()
          .limit(5);

      final List<dynamic> usersData = usersResponse as List<dynamic>? ?? [];
      _suggestedUsers = usersData
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .where((u) => u.id != currentUserId) // Hide self from suggestions
          .toList();

      // 3. Load follow relationships
      if (currentUserId != null) {
        final followingResponse = await supabaseClient
            .from('follows')
            .select('following_id')
            .eq('follower_id', currentUserId);

        final List<dynamic> followingData = followingResponse as List<dynamic>? ?? [];
        _myFollowingIds = followingData.map((item) => item['following_id'] as String).toSet();
      }
    } catch (e) {
      debugPrint("Explore data load failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final trimmedQuery = query.trim();
      if (trimmedQuery.isEmpty) {
        setState(() {
          _searchQuery = '';
          _searchResultsUsers = [];
          _searchResultsPosts = [];
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _searchQuery = trimmedQuery;
        _isSearching = true;
      });

      try {
        final supabaseClient = Supabase.instance.client;

        // Perform parallel users & posts searches
        final results = await Future.wait([
          supabaseClient
              .from('users')
              .select()
              .or('name.ilike.%$trimmedQuery%,username.ilike.%$trimmedQuery%')
              .limit(10),
          supabaseClient
              .from('posts')
              .select('*, author:users(id, name, avatar, profile_picture)')
              .or('title.ilike.%$trimmedQuery%,description.ilike.%$trimmedQuery%')
              .limit(12),
        ]);

        final List<dynamic> usersData = results[0] as List<dynamic>? ?? [];
        final List<dynamic> postsData = results[1] as List<dynamic>? ?? [];

        if (mounted) {
          setState(() {
            _searchResultsUsers = usersData.map((json) => UserModel.fromJson(json as Map<String, dynamic>)).toList();
            _searchResultsPosts = postsData.map((json) => PostModel.fromJson(json as Map<String, dynamic>)).toList();
          });
        }
      } catch (e) {
        debugPrint("Explore search query failed: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  Future<void> _handleFollowToggle(String targetUserId) async {
    final authRepo = ref.read(authRepositoryProvider);
    final currentUserId = authRepo.currentSupabaseUser?.id;
    if (currentUserId == null) return;

    final isFollowing = _myFollowingIds.contains(targetUserId);
    setState(() {
      if (isFollowing) {
        _myFollowingIds.remove(targetUserId);
      } else {
        _myFollowingIds.add(targetUserId);
      }
    });

    try {
      final finalFollowingState = await authRepo.toggleFollowUser(
        currentUserId,
        targetUserId,
        isFollowing,
      );
      if (finalFollowingState != _myFollowingIds.contains(targetUserId)) {
        setState(() {
          if (finalFollowingState) {
            _myFollowingIds.add(targetUserId);
          } else {
            _myFollowingIds.remove(targetUserId);
          }
        });
      }
    } catch (_) {
      setState(() {
        if (isFollowing) {
          _myFollowingIds.add(targetUserId);
        } else {
          _myFollowingIds.remove(targetUserId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update follow status')),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSearchingMode = _searchQuery.isNotEmpty;

    // Filter displayed posts by active category if not searching
    final List<PostModel> postsToDisplay = isSearchingMode
        ? _searchResultsPosts
        : (_activeCategory == 'All'
            ? _trendingPosts
            : _trendingPosts.where((p) => p.category == _activeCategory).toList());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              // Premium Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search accounts, stories, topics...',
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search_outlined),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Categories Horizontal Scroll List (Only when not in active search mode)
              if (!isSearchingMode)
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _activeCategory == cat;
                      final emoji = _categoryEmojis[cat] ?? '📁';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _activeCategory = cat;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              border: Border.all(
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadInitialExploreData,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            // Suggested Accounts / Users Search Results
                            if (isSearchingMode && _searchResultsUsers.isNotEmpty) ...[
                              _buildSectionHeader('Accounts', Icons.people_outline),
                              _buildAccountsList(_searchResultsUsers),
                            ] else if (!isSearchingMode && _suggestedUsers.isNotEmpty) ...[
                              _buildSectionHeader('Suggested for you', Icons.person_add_outlined),
                              _buildAccountsList(_suggestedUsers),
                            ],

                            // Posts Results Grid
                            _buildSectionHeader(
                              isSearchingMode
                                  ? 'Top Stories'
                                  : (_activeCategory == 'All' ? 'Trending Now' : _activeCategory),
                              Icons.trending_up,
                            ),

                            if (postsToDisplay.isEmpty)
                              _buildEmptyPlaceholder()
                            else
                              _buildEditorialGrid(postsToDisplay),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList(List<UserModel> users) {
    final theme = Theme.of(context);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        itemBuilder: (context, index) {
          final user = users[index];
          final isFollowing = _myFollowingIds.contains(user.id);
          final avatarUrl = user.resolvedAvatarUrl;
          final hasAvatar = avatarUrl.startsWith('http') && !avatarUrl.contains('ui-avatars.com');

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
              child: !hasAvatar
                  ? Text(
                      avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')
                          ? avatarUrl
                          : user.name.substring(0, 1).toUpperCase(),
                    )
                  : null,
            ),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: Text(
              '@${user.username ?? user.id.substring(0, 6)}${user.college != null ? ' • ${user.college}' : ''}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
            trailing: currentUserId != null && user.id != currentUserId
                ? TextButton(
                    onPressed: () => _handleFollowToggle(user.id),
                    style: TextButton.styleFrom(
                      backgroundColor: isFollowing ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primary,
                      foregroundColor: isFollowing ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(80, 32),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen(userId: user.id)),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEditorialGrid(List<PostModel> posts) {
    final List<Widget> children = [];
    int i = 0;
    int staggerIndex = 0;

    while (i < posts.length) {
      if (staggerIndex % 3 == 0) {
        // Large Card (Spans 2 columns / full-width)
        final post = posts[i];
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: _buildGridItem(post, isLarge: true),
            ),
          ),
        );
        i += 1;
      } else {
        // Two Small Cards side-by-side
        final post1 = posts[i];
        final post2 = (i + 1 < posts.length) ? posts[i + 1] : null;

        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.8,
                    child: _buildGridItem(post1, isLarge: false),
                  ),
                ),
                const SizedBox(width: 10),
                if (post2 != null)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.8,
                      child: _buildGridItem(post2, isLarge: false),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        );
        i += (post2 != null) ? 2 : 1;
      }
      staggerIndex++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildGridItem(PostModel post, {required bool isLarge}) {
    final theme = Theme.of(context);
    final color = _categoryColors[post.category] ?? Colors.blue[600]!;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: () {
          context.push('/article/${post.slug}');
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            post.imageUrl.isNotEmpty
                ? Image.network(
                    post.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildFallbackGridGradient(),
                  )
                : _buildFallbackGridGradient(),
            
            // Bottom gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.black45, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Contents overlay
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Category tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      post.category ?? 'News',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    post.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isLarge ? 15 : 12.5,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Stats row
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.redAccent, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        post.likes.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        post.comments.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
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

  Widget _buildFallbackGridGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withValues(alpha: 0.2), Colors.purple.withValues(alpha: 0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No matches found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Try searching for another account, story, or category.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}
