import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/transit_map/transit_map_screen.dart';
import 'features/station_detail/station_detail_screen.dart';
import 'features/paywall/paywall_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/subscription/subscription_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/email_auth_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final box = Hive.box('app_prefs');
    final isAuthed = box.get('auth_done') == 'true';

    if (!isAuthed && path != '/login' && path != '/login/email') return '/login';
    if (isAuthed && (path == '/login' || path == '/login/email')) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'map',
      builder: (ctx, state) => const TransitMapScreen(),
    ),
    GoRoute(
      path: '/station/:id',
      name: 'station_detail',
      pageBuilder: (ctx, state) => CustomTransitionPage(
        key: state.pageKey,
        child: StationDetailScreen(
          stationId: int.parse(state.pathParameters['id']!),
        ),
        transitionsBuilder: (ctx, animation, secondary, child) =>
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: '/paywall',
      name: 'paywall',
      builder: (ctx, state) => const PaywallScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (ctx, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/subscription',
      name: 'subscription',
      builder: (ctx, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (ctx, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/login/email',
      name: 'login_email',
      builder: (ctx, state) => const EmailAuthScreen(),
    ),
  ],
);
