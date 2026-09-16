import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spillcity/data/repositories/providers.dart';
import '../widgets/post_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  String activeCategory = 'All';
  bool isCategoryMenuOpen = false;

  final List<Map<String, String>> categoriesList = [
    {'name': 'Events', 'emoji': '🎉'},
    {'name': 'Notices', 'emoji': '📢'},
    {'name': 'Sports', 'emoji': '⚽'},
    {'name': 'Academic', 'emoji': '📚'},
    {'name': 'Clubs', 'emoji': '🎭'},
    {'name': 'Exams', 'emoji': '📝'},
    {'name': 'News', 'emoji': '📰'},
    {'name': 'College Daily Update', 'emoji': '🗓️'},
    {'name': 'Others', 'emoji': '✨'},
  ];

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(homeFeedPostsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SpillCity',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: ref.watch(unreadNotificationCountProvider).when(
                  data: (count) => count > 0
                      ? Badge(
                          label: Text('$count'),
                          child: const Icon(Icons.notifications_outlined),
                        )
                      : const Icon(Icons.notifications_outlined),
                  loading: () => const Icon(Icons.notifications_outlined),
                  error: (_, _) => const Icon(Icons.notifications_outlined),
                ),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Posts List
          postsAsync.when(
            data: (posts) {
              // Apply active category filtering
              final filteredPosts = activeCategory == 'All'
                  ? posts
                  : posts.where((p) => p.category == activeCategory).toList();

              if (filteredPosts.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(homeFeedPostsProvider.future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              activeCategory == 'All' ? '🌎' : '📭',
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No stories yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              activeCategory == 'All'
                                  ? 'Be the first to publish a story'
                                  : 'No stories in $activeCategory category',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Determine hero (first post in list)
              final hasHero = filteredPosts.isNotEmpty && filteredPosts[0].imageUrl.isNotEmpty;
              final heroPost = hasHero ? filteredPosts[0] : null;
              final listPosts = hasHero ? filteredPosts.sublist(1) : filteredPosts;

              return RefreshIndicator(
                onRefresh: () => ref.refresh(homeFeedPostsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: listPosts.length + (heroPost != null ? 2 : 1),
                  itemBuilder: (context, index) {
                    if (heroPost != null) {
                      if (index == 0) {
                        // Render Hero Card
                        return PostCard(
                          post: heroPost,
                          isHero: true,
                          onTap: () => context.push('/article/${heroPost.slug}'),
                          onLikeToggle: () {
                            final myId = Supabase.instance.client.auth.currentUser?.id;
                            if (myId != null) {
                              ref.read(postRepositoryProvider).toggleLike(heroPost.id, myId);
                            }
                          },
                          onSaveToggle: () {
                            final myId = Supabase.instance.client.auth.currentUser?.id;
                            if (myId != null) {
                              ref.read(postRepositoryProvider).toggleSave(heroPost.id, myId);
                            }
                          },
                        );
                      }
                      if (index == 1) {
                        // Section Header
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          child: Row(
                            children: [
                              Text(
                                activeCategory == 'All' ? 'Latest Stories' : activeCategory,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${listPosts.length + 1} stories',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      // Render Compact Card
                      final postItem = listPosts[index - 2];
                      return PostCard(
                        post: postItem,
                        isHero: false,
                        onTap: () => context.push('/article/${postItem.slug}'),
                        onLikeToggle: () {
                          final myId = Supabase.instance.client.auth.currentUser?.id;
                          if (myId != null) {
                            ref.read(postRepositoryProvider).toggleLike(postItem.id, myId);
                          }
                        },
                        onSaveToggle: () {
                          final myId = Supabase.instance.client.auth.currentUser?.id;
                          if (myId != null) {
                            ref.read(postRepositoryProvider).toggleSave(postItem.id, myId);
                          }
                        },
                      );
                    } else {
                      if (index == 0) {
                        // Section Header
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            activeCategory == 'All' ? 'Latest Stories' : activeCategory,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      // Render Compact Card
                      final postItem = listPosts[index - 1];
                      return PostCard(
                        post: postItem,
                        isHero: false,
                        onTap: () => context.push('/article/${postItem.slug}'),
                        onLikeToggle: () {
                          final myId = Supabase.instance.client.auth.currentUser?.id;
                          if (myId != null) {
                            ref.read(postRepositoryProvider).toggleLike(postItem.id, myId);
                          }
                        },
                        onSaveToggle: () {
                          final myId = Supabase.instance.client.auth.currentUser?.id;
                          if (myId != null) {
                            ref.read(postRepositoryProvider).toggleSave(postItem.id, myId);
                          }
                        },
                      );
                    }
                  },
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (err, stack) => RefreshIndicator(
              onRefresh: () => ref.refresh(homeFeedPostsProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Text('Failed to load feed: $err'),
                  ),
                ],
              ),
            ),
          ),

          // Category Popover Menu Overlay
          if (isCategoryMenuOpen) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  isCategoryMenuOpen = false;
                });
              },
              child: Container(
                color: Colors.black26, // Dim background overlay
              ),
            ),
            Positioned(
              bottom: 80,
              right: 16,
              child: Card(
                elevation: 8,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 180,
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(6),
                    children: [
                      // "All News" Row
                      _buildCategoryMenuItem(
                        emoji: '🌎',
                        name: 'All',
                        displayName: 'All news',
                      ),
                      const Divider(height: 1, indent: 8, endIndent: 8),
                      // Loop Categories
                      ...categoriesList.map((cat) => _buildCategoryMenuItem(
                            emoji: cat['emoji']!,
                            name: cat['name']!,
                            displayName: cat['name']!,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      // Floating Category button
      floatingActionButton: isCategoryMenuOpen
          ? null
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  isCategoryMenuOpen = true;
                });
              },
              backgroundColor: Colors.blue[600],
              elevation: 4,
              shape: const CircleBorder(),
              child: Text(
                activeCategory == 'All'
                    ? '🌎'
                    : categoriesList.firstWhere((c) => c['name'] == activeCategory)['emoji'] ?? '📁',
                style: const TextStyle(fontSize: 24),
              ),
            ),
    );
  }

  // Builder for list category popover options
  Widget _buildCategoryMenuItem({
    required String emoji,
    required String name,
    required String displayName,
  }) {
    final isSelected = activeCategory == name;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          activeCategory = name;
          isCategoryMenuOpen = false;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: isSelected ? Colors.blue.withValues(alpha: 0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  color: isSelected ? Colors.blue[700] : theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
