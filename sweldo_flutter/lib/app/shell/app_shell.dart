import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/effects.dart';
import '../../core/motion/interactive.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/external_link.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/logo.dart';
import '../../features/wallet/bloc/wallet_bloc.dart';
import '../../features/wallet/view/wallet_button.dart';
import '../../features/tour/tour_controller.dart';
import '../../features/tour/tour_overlay.dart';
import '../router/app_router.dart';
import '../../core/theme/sw_icons.dart';

/// Frame shared by every destination: top bar, network warning, navigation.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.current,
    required this.child,
    this.location = '/',
  });

  final AppRoute current;
  final Widget child;

  /// The exact path, so the guide knows when it must change page.
  final String location;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, next) =>
          next.message != null && previous.message != next.message,
      listener: (context, state) => _showMessage(context, state.message!),
      child: Stack(
        children: [
          Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(current: current, wide: wide),
                  const _WrongNetworkBanner(),
                  Expanded(child: child),
                ],
              ),
            ),
            bottomNavigationBar: wide ? null : _BottomNav(current: current),
          ),
          Positioned.fill(child: TourOverlay(currentPath: location)),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, WalletMessage message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message.text),
        duration: Duration(seconds: message.isError ? 8 : 4),
        action: message.walletMissing
            ? SnackBarAction(
                label: 'Get Freighter',
                onPressed: () =>
                    openExternal(Uri.parse('https://www.freighter.app/')),
              )
            : null,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.current, required this.wide});

  final AppRoute current;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: SwColors.paper,
        border: Border(bottom: BorderSide(color: SwColors.rule)),
      ),
      child: ContentWidth(
        child: Row(
          children: [
            SweldoLogo(onTap: () => context.go(AppRoute.overview.path)),
            if (wide) ...[
              const SizedBox(width: SwSpace.xxl),
              _TopNav(current: current),
            ],
            const Spacer(),
            const _NetworkChip(),
            const SizedBox(width: SwSpace.sm),
            const _GuideButton(),
            const SizedBox(width: SwSpace.sm),
            const TourTarget(id: 'connect', child: WalletButton()),
          ],
        ),
      ),
    );
  }
}

/// Inline destinations with an underline that slides to the active one.
class _TopNav extends StatelessWidget {
  const _TopNav({required this.current});

  final AppRoute current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final route in AppRoute.values)
          _TopNavItem(route: route, selected: route == current),
      ],
    );
  }
}

class _TopNavItem extends StatelessWidget {
  const _TopNavItem({required this.route, required this.selected});

  final AppRoute route;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final duration = SwMotion.of(context, const Duration(milliseconds: 200));
    return SizedBox(
      height: 67,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Interactive(
            onTap: () => context.go(route.path),
            selected: selected,
            semanticLabel: route.label,
            lift: 0,
            hoverShadow: false,
            radius: const BorderRadius.all(SwRadius.field),
            builder: (context, state) => AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: state.hovered && !selected
                    ? SwColors.stampWash
                    : Colors.transparent,
                borderRadius: const BorderRadius.all(SwRadius.field),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    scale: state.hovered ? 1.12 : 1,
                    child: Icon(
                      route.icon,
                      size: 17,
                      color: selected || state.hovered
                          ? SwColors.stamp
                          : SwColors.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 7),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    style: SwType.label.copyWith(
                      color: selected ? SwColors.ink : SwColors.inkMuted,
                    ),
                    child: Text(route.label),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: AnimatedScale(
              duration: SwMotion.of(context, SwMotion.standard),
              curve: SwMotion.enter,
              scale: selected ? 1 : 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  color: SwColors.stamp,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sweldo uses Stellar Testnet. Test money has no real value.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const BoxDecoration(
          color: SwColors.paydayWash,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PingDot(size: 7),
            const SizedBox(width: 7),
            Text(
              'Testnet',
              style: SwType.caption.copyWith(
                color: SwColors.payday,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrongNetworkBanner extends StatelessWidget {
  const _WrongNetworkBanner();

  @override
  Widget build(BuildContext context) {
    final session = context.select((WalletBloc b) => b.state.session);
    final show = session != null && !session.onTestnet;
    return AnimatedSize(
      duration: SwMotion.of(context, SwMotion.standard),
      curve: SwMotion.enter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: SwColors.cautionWash,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ContentWidth(
                child: Row(
                  children: [
                    const Icon(
                      SwIcons.warning,
                      size: 18,
                      color: SwColors.caution,
                    ),
                    const SizedBox(width: SwSpace.sm),
                    Expanded(
                      child: Text(
                        'Freighter is on ${session.network.isEmpty ? 'another network' : session.network}. '
                        'Switch it to Testnet before signing, then reconnect.',
                        style: SwType.bodySmall.copyWith(color: SwColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current});

  final AppRoute current;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SwColors.rule)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: SwColors.paper,
          surfaceTintColor: Colors.transparent,
          indicatorColor: SwColors.stampWash,
          height: 66,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => SwType.caption.copyWith(
              color: states.contains(WidgetState.selected)
                  ? SwColors.ink
                  : SwColors.inkMuted,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? SwColors.stamp
                  : SwColors.inkMuted,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: current.index,
          animationDuration: SwMotion.of(context, SwMotion.standard),
          onDestinationSelected: (index) =>
              context.go(AppRoute.values[index].path),
          destinations: [
            for (final route in AppRoute.values)
              NavigationDestination(
                icon: Icon(route.icon),
                selectedIcon: Icon(route.selectedIcon),
                label: route.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the highlighting guide.
class _GuideButton extends StatelessWidget {
  const _GuideButton();

  @override
  Widget build(BuildContext context) {
    final compact = !isWide(context);
    final duration = SwMotion.of(context, const Duration(milliseconds: 200));
    return Interactive(
      onTap: () => TourScope.read(context)?.start(),
      tooltip: 'Show me around',
      semanticLabel: 'Open the guide',
      radius: const BorderRadius.all(Radius.circular(999)),
      builder: (context, state) => AnimatedContainer(
        duration: duration,
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: state.hovered ? SwColors.stamp : SwColors.rule,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: state.hovered ? 0.125 : 0,
              duration: duration,
              child: Icon(
                SwIcons.guide,
                size: 16,
                color: state.hovered ? SwColors.stamp : SwColors.inkMuted,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                'Guide',
                style: SwType.label.copyWith(
                  fontSize: 13,
                  color: state.hovered ? SwColors.stamp : SwColors.ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
