import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/shell/page_frame.dart';
import '../../../core/config/app_config.dart';
import '../../../core/motion/effects.dart';
import '../../../core/motion/tilt.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/widgets/logo.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/widgets/punch_card.dart';
import '../../../core/widgets/sw_button.dart';
import '../../account/bloc/account_setup_cubit.dart';
import '../../account/view/account_setup_prompts.dart';
import '../../conversion/data/conversion_repository.dart';
import '../../conversion/domain/conversion_pair.dart';
import '../../conversion/view/conversion_receipt_card.dart';
import '../../conversion/view/conversion_sheet.dart';
import '../../wallet/bloc/wallet_bloc.dart';
import '../../tour/tour_controller.dart';
import '../../wallet/view/connect_wallet_sheet.dart';
import '../bloc/payouts_bloc.dart';
import '../domain/payout.dart';
import 'widgets/claim_history_list.dart';
import 'widgets/payout_row.dart';
import 'widgets/wallet_overview.dart';
import '../../../core/theme/sw_icons.dart';

class EmployeePage extends StatelessWidget {
  const EmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.select((WalletBloc b) => b.state.session);
    final bloc = context.read<PayoutsBloc>();
    return PageFrame(
      title: 'My pay',
      description:
          'Your salary on Stellar. Each payout unlocks on its payday, '
          'and you claim it straight to your wallet.',
      onRefresh: session == null
          ? null
          : () async {
              bloc.add(const PayoutsRefreshRequested());
              await context.read<AccountSetupCubit>().refresh();
              await bloc.stream.firstWhere((s) => !s.loading);
            },
      child: AnimatedSwitcher(
        duration: SwMotion.of(context, SwMotion.standard),
        child: session == null
            ? const _ConnectPrompt(key: ValueKey('connect'))
            : _PayView(
                key: ValueKey(session.address),
                address: session.address,
              ),
      ),
    );
  }
}

/// A compact, centred invitation to connect: everything on one axis, no
/// empty half-panel.
class _ConnectPrompt extends StatelessWidget {
  const _ConnectPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Panel(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsive(SwSpace.xl, sm: SwSpace.xxxl),
            vertical: SwSpace.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Tilt3D(
                maxTilt: 18,
                baseX: 8,
                radius: BorderRadius.all(Radius.circular(22)),
                child: _WalletTile(),
              ),
              const SizedBox(height: SwSpace.xl),
              Text(
                'Connect to see your pay',
                style: SwType.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SwSpace.sm),
              Text(
                'Use the Freighter wallet your employer added to the payroll. '
                'Your payouts are read straight from the Stellar ledger.',
                style: SwType.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SwSpace.xl),
              TourTarget(
                id: 'connect-pay',
                child: SwButton(
                  label: 'Connect Freighter',
                  icon: SwIcons.wallet,
                  large: true,
                  onPressed: () => showConnectWalletSheet(context),
                ),
              ),
              const SizedBox(height: SwSpace.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: SwSpace.lg,
                runSpacing: SwSpace.xs,
                children: const [
                  _Hint(icon: SwIcons.extension, text: 'Browser extension'),
                  _Hint(icon: SwIcons.phone, text: 'Freighter app'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wallet glyph on a raised violet tile that leans toward the pointer.
class _WalletTile extends StatelessWidget {
  const _WalletTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SweldoBrand.violetLight, SweldoBrand.violetDark],
        ),
        boxShadow: [
          BoxShadow(
            color: SwColors.stamp.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
        ],
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(SwIcons.wallet, color: Colors.white, size: 34),
          Positioned(
            top: 12,
            right: 12,
            child: PingDot(color: Colors.white, size: 7),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: SwColors.inkMuted),
        const SizedBox(width: 6),
        Text(text, style: SwType.caption),
      ],
    );
  }
}

class _PayView extends StatelessWidget {
  const _PayView({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final state = context.watch<PayoutsBloc>().state;
    final bloc = context.read<PayoutsBloc>();
    final pair = config.conversionPair;
    final open = state.openPayouts;
    final assetLabel = open.isEmpty ? config.assetLabel : open.first.assetCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WalletOverview(
          address: address,
          totalUnits: state.totalUnits,
          assetLabel: assetLabel,
          activeCount: open.length,
          loading: state.loading,
          onRefresh: () => bloc.add(const PayoutsRefreshRequested()),
        ),
        const SizedBox(height: SwSpace.lg),
        AnimatedNotice(
          state.notice,
          padding: const EdgeInsets.only(bottom: SwSpace.lg),
        ),
        AnimatedSize(
          duration: SwMotion.of(context, SwMotion.standard),
          curve: SwMotion.enter,
          alignment: Alignment.topCenter,
          child: state.receipt == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: SwSpace.lg),
                  child: ConversionReceiptCard(receipt: state.receipt!),
                ),
        ),
        const AccountSetupPrompts(
          trustlineMessage:
              'Add a trustline so this wallet can receive the payroll asset '
              'before you claim.',
        ),
        const SizedBox(height: SwSpace.md),
        SectionHeading(
          title: 'Pay schedule',
          description: 'Payouts addressed to your wallet, soonest first.',
          trailing: Text(
            '${state.payouts.length} on the ledger',
            style: SwType.caption,
          ),
        ),
        const SizedBox(height: SwSpace.lg),
        AnimatedSize(
          duration: SwMotion.of(context, SwMotion.deliberate),
          curve: SwMotion.enter,
          alignment: Alignment.topCenter,
          child: TourTarget(
            id: 'pay-schedule',
            child: _timeline(context, state, pair),
          ),
        ),
        const SizedBox(height: SwSpace.xxl),
        TourTarget(
          id: 'claim-history',
          child: ClaimHistoryList(
            history: state.history,
            assetLabel: config.assetLabel,
            freshKey: state.freshClaimKey,
          ),
        ),
      ],
    );
  }

  Widget _timeline(
    BuildContext context,
    PayoutsState state,
    ConversionPair? pair,
  ) {
    final bloc = context.read<PayoutsBloc>();
    if (!state.loaded && state.loading) {
      return const _LedgerLoading();
    }
    if (state.payouts.isEmpty) {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No pay scheduled yet', style: SwType.subtitle),
            const SizedBox(height: SwSpace.xs),
            Text(
              'Ask your employer to lock a payroll for ${shortKey(address, 8)}, '
              'then refresh.',
              style: SwType.bodySmall,
            ),
            const SizedBox(height: SwSpace.lg),
            SwButton(
              label: 'Refresh',
              icon: SwIcons.refresh,
              tone: SwButtonTone.secondary,
              loading: state.loading,
              onPressed: () => bloc.add(const PayoutsRefreshRequested()),
            ),
          ],
        ),
      );
    }
    // Soonest payday first: that's the order paydays arrive in.
    final payouts = [...state.payouts]
      ..sort((a, b) {
        final at = a.unlockTimeFor(address) ?? DateTime(0);
        final bt = b.unlockTimeFor(address) ?? DateTime(0);
        return at.compareTo(bt);
      });
    return PayrollPaper(
      children: [
        for (final payout in payouts)
          PayoutRow(
            key: ValueKey(payout.balanceId),
            payout: payout,
            address: address,
            claiming: state.claimingId == payout.balanceId,
            disabled: state.claimingId != null || state.loading,
            claimedHash: state.claimedHashes[payout.balanceId],
            onClaim: () => bloc.add(PayoutClaimRequested(payout)),
            onConvert: supportsConversion(payout, pair)
                ? () => _convert(context, payout)
                : null,
          ),
      ],
    );
  }

  Future<void> _convert(BuildContext context, Payout payout) async {
    final pair = context.read<AppConfig>().conversionPair;
    if (pair == null) return;
    final bloc = context.read<PayoutsBloc>();
    final receipt = await showConversionSheet(
      context,
      address: address,
      payout: payout,
      pair: pair,
    );
    if (receipt != null) bloc.add(PayoutConversionCompleted(receipt));
  }
}

/// Pulsing placeholder rows while the ledger is read.
class _LedgerLoading extends StatelessWidget {
  const _LedgerLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Reading the Stellar ledger',
      child: PayrollPaper(
        children: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.all(SwSpace.lg),
              child: Row(
                children: [
                  Skeleton(width: 14, height: 22, radius: 7),
                  SizedBox(width: SwSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 120, height: 18),
                        SizedBox(height: 8),
                        Skeleton(width: 190, height: 12),
                      ],
                    ),
                  ),
                  Skeleton(width: 88, height: 30, radius: 999),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
