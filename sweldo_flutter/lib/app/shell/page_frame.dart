import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/app_config.dart';
import '../../core/stellar/stellar_network.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/external_link.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/logo.dart';

/// A scrolling destination with an optional page title and the footer.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.title,
    this.description,
    this.onRefresh,
  });

  final String? title;
  final String? description;
  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: ContentWidth(
            child: Padding(
              padding: EdgeInsets.only(
                top: wide ? SwSpace.xxxl : SwSpace.xl,
                bottom: SwSpace.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: wide
                          ? SwType.headline
                          : SwType.headline.copyWith(fontSize: 30),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: SwSpace.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Text(
                          description!,
                          style: SwType.body.copyWith(color: SwColors.inkMuted),
                        ),
                      ),
                    ],
                    SizedBox(height: wide ? SwSpace.xxl : SwSpace.xl),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Align(alignment: Alignment.bottomCenter, child: _Footer()),
        ),
      ],
    );
    if (onRefresh == null) return scroll;
    return RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SwColors.rule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: SwSpace.xl),
      child: ContentWidth(
        child: Wrap(
          spacing: SwSpace.xl,
          runSpacing: SwSpace.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SweldoLogo(compact: true),
            Text(
              'Payroll that keeps its promise. Built on Stellar Testnet.',
              style: SwType.bodySmall,
            ),
            ExternalLink(
              label: 'Stellar Expert',
              uri: Uri.parse(Explorer.home),
              style: SwType.bodySmall,
            ),
            if (config.hasRegistry)
              ExternalLink(
                label:
                    'Payroll registry ${shortKey(config.registryContractId, 4)}',
                uri: Explorer.contract(config.registryContractId),
                style: SwType.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
