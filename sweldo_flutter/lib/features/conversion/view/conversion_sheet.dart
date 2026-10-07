import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stellar/stellar_network.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/amount.dart';
import '../../../core/widgets/external_link.dart';
import '../../../core/widgets/key_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/widgets/sw_button.dart';
import '../../payouts/domain/payout.dart';
import '../bloc/conversion_bloc.dart';
import '../data/conversion_repository.dart';
import '../domain/conversion_pair.dart';
import '../domain/conversion_quote.dart';
import '../../../core/theme/sw_icons.dart';

/// Opens claim-and-convert for [payout]. Resolves with the receipt when the
/// conversion lands, or null if the person closes it.
Future<ConversionReceipt?> showConversionSheet(
  BuildContext context, {
  required String address,
  required Payout payout,
  required ConversionPair pair,
}) {
  final repository = context.read<ConversionRepository>();
  Widget content(BuildContext _) => BlocProvider(
    create: (_) => ConversionBloc(
      repository: repository,
      address: address,
      balanceId: payout.balanceId,
      pair: pair,
    )..add(const ConversionQuoteRequested()),
    child: _ConversionContent(payout: payout),
  );

  if (isWide(context)) {
    return showDialog<ConversionReceipt>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(SwSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(SwSpace.xl),
            child: content(dialogContext),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<ConversionReceipt>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SwSpace.xl,
          0,
          SwSpace.xl,
          SwSpace.xl,
        ),
        child: content(sheetContext),
      ),
    ),
  );
}

class _ConversionContent extends StatelessWidget {
  const _ConversionContent({required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConversionBloc, ConversionState>(
      listenWhen: (previous, next) =>
          previous.receipt == null && next.receipt != null,
      listener: (context, state) => Navigator.of(context).pop(state.receipt),
      builder: (context, state) {
        final bloc = context.read<ConversionBloc>();
        return SecondTicker(
          builder: (context, now) {
            final quote = state.quote;
            final expired = quote != null && quote.isExpired(now);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Claim as PHPT', style: SwType.title)),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: state.signing
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(SwIcons.close),
                    ),
                  ],
                ),
                Text(
                  'Claim ${Amount.format(payout.amount)} test-USDC and receive '
                  'PHPT in your connected wallet, in one transaction.',
                  style: SwType.bodySmall,
                ),
                const SizedBox(height: SwSpace.xl),
                AnimatedSize(
                  duration: SwMotion.of(context, SwMotion.standard),
                  curve: SwMotion.enter,
                  alignment: Alignment.topCenter,
                  child: state.loading
                      ? const _Checking()
                      : quote == null
                      ? const SizedBox(width: double.infinity)
                      : _QuoteDetails(quote: quote, now: now),
                ),
                AnimatedNotice(
                  state.error == null ? null : NoticeData.error(state.error!),
                  padding: const EdgeInsets.only(top: SwSpace.lg),
                ),
                if (state.uncertainHash != null) ...[
                  const SizedBox(height: SwSpace.md),
                  Text(
                    'Check this transaction before retrying:',
                    style: SwType.caption,
                  ),
                  KeyText(state.uncertainHash!, edge: 10),
                  ExternalLink(
                    label: 'Open on Stellar Expert',
                    uri: Explorer.transaction(state.uncertainHash!),
                  ),
                ],
                const SizedBox(height: SwSpace.lg),
                Text(
                  'Test assets have no real value. If the conversion fails, the '
                  'payout stays unclaimed. A submitted transaction may still '
                  'charge a network fee.',
                  style: SwType.caption,
                ),
                const SizedBox(height: SwSpace.xl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: SwSpace.sm,
                  runSpacing: SwSpace.sm,
                  children: [
                    SwButton(
                      label: 'Refresh quote',
                      icon: SwIcons.refresh,
                      tone: SwButtonTone.secondary,
                      onPressed: state.loading || state.signing || state.locked
                          ? null
                          : () => bloc.add(const ConversionQuoteRequested()),
                    ),
                    SwButton(
                      label: state.signing
                          ? 'Confirm in Freighter…'
                          : 'Claim and convert',
                      icon: SwIcons.convert,
                      loading: state.signing,
                      onPressed:
                          quote == null ||
                              expired ||
                              state.loading ||
                              state.locked
                          ? null
                          : () => bloc.add(const ConversionConfirmed()),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: SwSpace.md),
          Expanded(
            child: Text(
              'Checking the payout, trustlines and liquidity…',
              style: SwType.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteDetails extends StatelessWidget {
  const _QuoteDetails({required this.quote, required this.now});

  final ConversionQuote quote;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final left = quote.remaining(now);
    final expired = quote.isExpired(now);
    final fraction = left.inMilliseconds / quoteLifetime.inMilliseconds;
    final rows = [
      ('Payout', '${Amount.format(quote.sendAmount)} test-USDC'),
      ('You receive about', '${Amount.format(quote.expectedAmount)} PHPT'),
      ('At least', '${Amount.format(quote.minimumAmount)} PHPT'),
      ('Price may move', 'Up to 1%'),
    ];
    final missing = quote.missingTrustlines.map((a) => a.code).join(' and ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(SwRadius.panel),
            border: Border.all(color: SwColors.rule),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  color: i.isEven
                      ? SwColors.greenbar.withValues(alpha: 0.5)
                      : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SwSpace.lg,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(rows[i].$1, style: SwType.bodySmall),
                      ),
                      Text(rows[i].$2, style: SwType.figures),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SwSpace.lg,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Quote', style: SwType.bodySmall)),
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        value: fraction.clamp(0.0, 1.0),
                        strokeWidth: 2.4,
                        color: expired ? SwColors.danger : SwColors.stamp,
                        backgroundColor: SwColors.greenbar,
                      ),
                    ),
                    const SizedBox(width: SwSpace.sm),
                    Text(
                      expired
                          ? 'Expired. Refresh it.'
                          : '${left.inSeconds}s left',
                      style: SwType.figures.copyWith(
                        color: expired ? SwColors.danger : SwColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SwSpace.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              missing.isEmpty ? SwIcons.success : SwIcons.trustline,
              size: 20,
              color: missing.isEmpty ? SwColors.payday : SwColors.stamp,
            ),
            const SizedBox(width: SwSpace.md),
            Expanded(
              child: Text(
                missing.isEmpty
                    ? 'Your wallet can already hold both test assets.'
                    : 'Sweldo adds $missing to your wallet in the same '
                          'transaction. Keep some test XLM for reserves and fees.',
                style: SwType.bodySmall.copyWith(color: SwColors.ink),
              ),
            ),
          ],
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: SwSpace.sm),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text('Test asset issuers', style: SwType.label),
            children: [
              Text('USDC', style: SwType.caption),
              KeyText(quote.source.issuerId, edge: 10),
              Text('PHPT', style: SwType.caption),
              KeyText(quote.destination.issuerId, edge: 10),
            ],
          ),
        ),
      ],
    );
  }
}
