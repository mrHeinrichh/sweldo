import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/account/bloc/account_setup_cubit.dart';
import '../features/payouts/bloc/payouts_bloc.dart';
import '../features/payroll/bloc/payroll_form/payroll_form_bloc.dart';
import '../features/payroll/bloc/schedules/schedules_bloc.dart';
import '../features/wallet/bloc/wallet_bloc.dart';
import '../features/tour/tour_controller.dart';
import '../features/tour/tour_steps.dart';
import 'dependencies.dart';
import '../features/story/view/story_page.dart';
import 'router/app_router.dart';

class SweldoApp extends StatefulWidget {
  const SweldoApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<SweldoApp> createState() => _SweldoAppState();
}

class _SweldoAppState extends State<SweldoApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.dependencies.config.storyDemo
        ? StoryPage.path
        : AppRoute.overview.path,
  );

  late final TourController _tour = TourController(
    steps: sweldoTour,
    store: widget.dependencies.store,
  );

  @override
  void initState() {
    super.initState();
    // First visit: offer the guide once (not in presentation mode).
    if (!_tour.hasBeenSeen && !widget.dependencies.config.storyDemo) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && !_tour.isOpen) _tour.start();
      });
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _tour.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: deps),
        RepositoryProvider.value(value: deps.config),
        RepositoryProvider.value(value: deps.wallet),
        RepositoryProvider.value(value: deps.conversion),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                WalletBloc(repository: deps.wallet, horizon: deps.horizon)
                  ..add(const WalletStarted()),
          ),
          BlocProvider(
            create: (_) => AccountSetupCubit(
              repository: deps.account,
              wallet: deps.wallet,
              payrollAsset: deps.config.payrollAsset,
            ),
          ),
          // Form and lists live above the router so they survive tab switches.
          BlocProvider(
            create: (_) => PayrollFormBloc(
              payroll: deps.payroll,
              registry: deps.registry,
              store: deps.schedules,
              asset: deps.config.payrollAsset,
              assetLabel: deps.config.assetLabel,
            ),
          ),
          BlocProvider(
            create: (_) => SchedulesBloc(
              store: deps.schedules,
              payroll: deps.payroll,
              wallet: deps.wallet,
            ),
          ),
          BlocProvider(
            create: (_) => PayoutsBloc(
              repository: deps.payouts,
              historyStore: deps.claimHistory,
              wallet: deps.wallet,
            ),
          ),
        ],
        child: TourScope(
          controller: _tour,
          child: MaterialApp.router(
            title: 'Sweldo',
            debugShowCheckedModeBanner: false,
            theme: SwTheme.light(),
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
