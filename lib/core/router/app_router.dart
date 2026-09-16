import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spillcity/data/repositories/providers.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/auth/screens/signup_screen.dart';
import '../../presentation/auth/screens/onboarding_screen.dart';
import '../../presentation/auth/screens/welcome_screen.dart';
import '../../presentation/feed/screens/article_detail_screen.dart';
import '../../presentation/notifications/notifications_screen.dart';
import '../../presentation/create/create_post_screen.dart';
import '../../main.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable(ref);
  
  ref.onDispose(() {
    refreshListenable.dispose();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = supabaseUser != null;

      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isWelcome = state.matchedLocation == '/welcome';

      if (!isLoggedIn) {
        if (isLoggingIn || isSigningUp || isWelcome) return null;
        return '/welcome';
      }

      // Read current profile status without subscribing to re-creation
      final currentUserAsync = ref.read(currentUserProvider);
      final userProfile = currentUserAsync.valueOrNull;
      
      // If the cached profile belongs to a different user, it's a mismatch (still loading the new profile)
      final hasMismatchedProfile = userProfile != null && userProfile.id != supabaseUser.id;
      final isProfileLoading = currentUserAsync.isLoading || hasMismatchedProfile;
      
      // Wait for profile loading to determine redirect
      if (isProfileLoading) {
        if (isLoggingIn || isSigningUp || isOnboarding || isWelcome) return null;
        return null;
      }

      final onboardingComplete = userProfile?.onboardingComplete ?? false;

      if (!onboardingComplete) {
        if (isOnboarding) return null;
        return '/onboarding';
      }

      // If logged in & onboarding complete, redirect away from auth/onboarding pages to feed
      if (isLoggingIn || isSigningUp || isOnboarding || isWelcome) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/article/:slug',
        builder: (context, state) => ArticleDetailScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) {
          final editId = state.uri.queryParameters['edit'];
          return CreatePostScreen(editPostId: editId);
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainTabContainer(),
      ),
    ],
  );
});

class _RouterRefreshListenable extends ChangeNotifier {
  late final ProviderSubscription _authSubscription;
  late final ProviderSubscription _userSubscription;

  _RouterRefreshListenable(Ref ref) {
    // Listen to Auth State Changes
    _authSubscription = ref.listen(
      authStateProvider,
      (previous, next) => notifyListeners(),
      fireImmediately: true,
    );

    // Listen to Current User Profile Changes
    _userSubscription = ref.listen(
      currentUserProvider,
      (previous, next) => notifyListeners(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authSubscription.close();
    _userSubscription.close();
    super.dispose();
  }
}
