import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/theme_provider.dart';
import 'presentation/feed/screens/feed_screen.dart';
import 'presentation/shared/left_sidebar.dart';
import 'presentation/shared/right_sidebar.dart';
import 'presentation/profile/screens/profile_screen.dart';
import 'presentation/explore/explore_screen.dart';
import 'presentation/create/create_post_screen.dart';
import 'presentation/messages/screens/conversations_screen.dart';
import 'presentation/notifications/notifications_screen.dart';
import 'presentation/call/providers/global_call_manager.dart';
import 'core/router/app_router.dart';
import 'data/repositories/providers.dart';
import 'dart:io';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'services/notification_service.dart';

import 'core/constants/app_config.dart';

final supabaseInitializedProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    try {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    } catch (e) {
      debugPrint("Failed to apply sqlite3 workaround: $e");
    }
  }

  // Initialize Firebase (wrapped in try-catch to prevent crash if google-services.json is missing)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase initialization failed (possibly missing google-services.json): $e");
  }

  final container = ProviderContainer();

  // Initialize Supabase in the background asynchronously
  Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  ).then((_) {
    container.read(supabaseInitializedProvider.notifier).state = true;
  }).catchError((e) {
    debugPrint("Failed to initialize Supabase: $e");
    container.read(supabaseInitializedProvider.notifier).state = true;
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ProxyPressApp(),
    ),
  );
}

class ProxyPressApp extends ConsumerWidget {
  const ProxyPressApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInitialized = ref.watch(supabaseInitializedProvider);
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    if (!isInitialized) {
      final isDark = themeSettings.themeMode == ThemeMode.dark ||
          (themeSettings.themeMode == ThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.dark);
      return MaterialApp(
        title: 'SpillCity',
        theme: themeNotifier.getThemeData(false),
        darkTheme: themeNotifier.getThemeData(true),
        themeMode: themeSettings.themeMode,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: themeNotifier.getThemeData(isDark).scaffoldBackgroundColor,
          body: const SizedBox.shrink(),
        ),
      );
    }

    // Initialize notification service asynchronously once Supabase is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize(ref);
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SpillCity',
      theme: themeNotifier.getThemeData(false),
      darkTheme: themeNotifier.getThemeData(true),
      themeMode: themeSettings.themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return GlobalCallManager(child: child!);
      },
    );
  }
}
class MainTabContainer extends ConsumerStatefulWidget {
  const MainTabContainer({super.key});

  @override
  ConsumerState<MainTabContainer> createState() => _MainTabContainerState();
}

class _MainTabContainerState extends ConsumerState<MainTabContainer> {
  int _currentIndex = 0;
  DateTime? _lastPressedAt;

  final List<Widget> _screens = [
    const FeedScreen(),
    const ExploreScreen(),
    const CreatePostScreen(),
    const NotificationsScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        ref.read(syncServiceProvider).syncAllUserData(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width > 900;

    Widget mainLayout;

    if (isWide) {
      // 💻 Desktop Layout (Three-Column Layout matching LeftSidebar + Feed + RightSidebar)
      mainLayout = Scaffold(
        body: Row(
          children: [
            // Left Navigation Sidebar (width: 260px)
            LeftSidebar(
              currentIndex: _currentIndex,
              onTabSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            // Middle Content Area containing the active screen (constrained to max 640px)
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _screens[_currentIndex],
                ),
              ),
            ),
            // Right Widgets Sidebar (width: 300px)
            const RightSidebar(),
          ],
        ),
      );
    } else {
      final activeConvId = ref.watch(activeConversationIdProvider);
      final showBottomBar = _currentIndex == 4 && activeConvId != null ? false : true;

      // 📱 Mobile Layout (Single screen + Custom Bottom Navigation Bar matching TypeScript/CSS)
      mainLayout = Scaffold(
        body: SafeArea(
          top: false,
          child: _screens[_currentIndex],
        ),
        bottomNavigationBar: showBottomBar ? _buildCustomBottomNav(context) : null,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If we are not on the Home tab, navigate back to the Home tab first
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // 2. If on the Home tab, require double back press to exit
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // If pressed twice within 2 seconds, exit the application
        await SystemNavigator.pop();
      },
      child: mainLayout,
    );
  }

  Widget _buildCustomBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Read unread direct messages count
    final unreadMessagesCount = ref.watch(unreadMessageCountProvider).valueOrNull ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: Row(
            children: [
              // Home
              Expanded(
                child: _buildNavItem(
                  targetIndex: 0,
                  label: 'Home',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  theme: theme,
                ),
              ),
              // Explore
              Expanded(
                child: _buildNavItem(
                  targetIndex: 1,
                  label: 'Explore',
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search,
                  theme: theme,
                ),
              ),
              // Create (Raised floating button matching Capacitor web)
              Expanded(
                child: _buildCreateNavItem(theme),
              ),
              // Messages
              Expanded(
                child: _buildNavItem(
                  targetIndex: 4,
                  label: 'Messages',
                  icon: Icons.mail_outlined,
                  activeIcon: Icons.mail,
                  badgeCount: unreadMessagesCount,
                  theme: theme,
                ),
              ),
              // Profile
              Expanded(
                child: _buildNavItem(
                  targetIndex: 5,
                  label: 'Profile',
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateNavItem(ThemeData theme) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = 2;
          });
        },
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int targetIndex,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    int badgeCount = 0,
    required ThemeData theme,
  }) {
    final isActive = _currentIndex == targetIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _currentIndex = targetIndex;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: isActive ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  size: 24,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    alignment: Alignment.center,
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
