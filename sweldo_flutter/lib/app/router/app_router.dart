import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../features/home/view/home_page.dart';
import '../../features/payouts/view/employee_page.dart';
import '../../features/payroll/view/employer_page.dart';
import '../../features/story/view/story_page.dart';
import '../shell/app_shell.dart';
import '../../core/theme/sw_icons.dart';

/// Top-level destinations, in navigation order.
enum AppRoute {
  overview('/', 'Overview', SwIcons.overview, SwIcons.overview),
  employer('/employer', 'Pay your team', SwIcons.team, SwIcons.team),
  employee('/pay', 'My pay', SwIcons.wallet, SwIcons.wallet);

  const AppRoute(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static AppRoute fromLocation(String location) => AppRoute.values.firstWhere(
    (route) => route != overview && location.startsWith(route.path),
    orElse: () => overview,
  );
}

GoRouter buildRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          current: AppRoute.fromLocation(state.uri.path),
          location: state.uri.path,
          child: child,
        ),
        routes: [
          _route(AppRoute.overview, (_) => const HomePage()),
          _route(AppRoute.employer, (_) => const EmployerPage()),
          _route(AppRoute.employee, (_) => const EmployeePage()),
          _page(StoryPage.path, 'story', (_) => const StoryPage()),
        ],
      ),
    ],
  );
}

/// Switching destinations fades through: the old page recedes before the new
/// one arrives, so the two never overlap.
GoRoute _route(AppRoute route, WidgetBuilder builder) =>
    _page(route.path, route.name, builder);

GoRoute _page(String path, String name, WidgetBuilder builder) {
  return GoRoute(
    path: path,
    name: name,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: Builder(builder: builder),
      transitionDuration: SwMotion.of(context, SwMotion.deliberate),
      reverseTransitionDuration: SwMotion.of(context, SwMotion.standard),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondary,
            fillColor: SwColors.paper,
            child: child,
          ),
    ),
  );
}
