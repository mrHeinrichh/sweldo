import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/motion/interactive.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/external_link.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sw_button.dart';
import '../bloc/wallet_bloc.dart';
import '../data/wallet_connector.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_session.dart';
import '../../../core/theme/sw_icons.dart';

/// Opens the wallet picker as a bottom sheet on phones and a dialog on wide
/// screens. Closes itself once a wallet connects.
Future<void> showConnectWalletSheet(BuildContext context) async {
  final bloc = context.read<WalletBloc>();
  final repository = context.read<WalletRepository>();
  final content = BlocProvider.value(
    value: bloc,
    child: _ConnectWalletContent(connectors: repository.connectors),
  );
  if (isWide(context)) {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(SwSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(SwSpace.xl),
            child: content,
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SwSpace.xl,
            0,
            SwSpace.xl,
            SwSpace.xl,
          ),
          child: content,
        ),
      ),
    );
  }
  if (bloc.state.status == WalletStatus.connecting) {
    bloc.add(const WalletPairingDismissed());
  }
}

class _ConnectWalletContent extends StatelessWidget {
  const _ConnectWalletContent({required this.connectors});

  final List<WalletConnector> connectors;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletBloc, WalletState>(
      listenWhen: (previous, next) =>
          previous.session != next.session && next.session != null,
      listener: (context, state) => Navigator.of(context).maybePop(),
      builder: (context, state) {
        final pairing = state.pairingUri;
        return AnimatedSize(
          duration: SwMotion.of(context, SwMotion.standard),
          curve: SwMotion.enter,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: SwMotion.of(context, SwMotion.standard),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
                    .animate(
                      CurvedAnimation(parent: animation, curve: SwMotion.enter),
                    ),
                child: child,
              ),
            ),
            child: pairing == null
                ? _WalletChoices(
                    key: const ValueKey('choices'),
                    connectors: connectors,
                    state: state,
                  )
                : _PairingView(key: ValueKey(pairing), uri: pairing),
          ),
        );
      },
    );
  }
}

class _WalletChoices extends StatelessWidget {
  const _WalletChoices({
    super.key,
    required this.connectors,
    required this.state,
  });

  final List<WalletConnector> connectors;
  final WalletState state;

  @override
  Widget build(BuildContext context) {
    // Lead with the option that fits this device.
    final ordered = [...connectors]
      ..sort((a, b) {
        int rank(WalletConnector c) => c.isAvailable ? 0 : 1;
        return rank(a).compareTo(rank(b));
      });
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Connect Freighter', style: SwType.title),
        const SizedBox(height: SwSpace.sm),
        Text(
          'Freighter signs each transaction after you review it. Sweldo never '
          'sees your keys.',
          style: SwType.bodySmall,
        ),
        const SizedBox(height: SwSpace.xl),
        for (final connector in ordered) ...[
          _WalletOption(
            connector: connector,
            busy: state.connectingKind == connector.kind,
            enabled:
                connector.isAvailable &&
                state.status != WalletStatus.connecting,
          ),
          const SizedBox(height: SwSpace.md),
        ],
        const SizedBox(height: SwSpace.sm),
        Row(
          children: [
            Text("Don't have Freighter? ", style: SwType.bodySmall),
            ExternalLink(
              label: 'Get it at freighter.app',
              uri: Uri.parse('https://www.freighter.app/'),
              style: SwType.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class _WalletOption extends StatelessWidget {
  const _WalletOption({
    required this.connector,
    required this.busy,
    required this.enabled,
  });

  final WalletConnector connector;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final kind = connector.kind;
    final icon = kind == WalletKind.freighterExtension
        ? SwIcons.extension
        : SwIcons.phone;
    final duration = SwMotion.of(context, const Duration(milliseconds: 200));
    return Interactive(
      onTap: enabled
          ? () => context.read<WalletBloc>().add(WalletConnectRequested(kind))
          : null,
      semanticLabel: kind.title,
      radius: const BorderRadius.all(SwRadius.panel),
      shadowColor: SwColors.stamp,
      builder: (context, state) => AnimatedContainer(
        duration: duration,
        padding: const EdgeInsets.all(SwSpace.lg),
        decoration: BoxDecoration(
          color: state.hovered ? SwColors.stampWash : Colors.white,
          borderRadius: const BorderRadius.all(SwRadius.panel),
          border: Border.all(
            color: busy || state.hovered ? SwColors.stamp : SwColors.rule,
          ),
        ),
        child: Opacity(
          opacity: connector.isAvailable ? 1 : 0.55,
          child: Row(
            children: [
              AnimatedContainer(
                duration: duration,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: state.hovered ? SwColors.stamp : SwColors.stampWash,
                  borderRadius: const BorderRadius.all(SwRadius.field),
                ),
                child: Icon(
                  icon,
                  color: state.hovered ? Colors.white : SwColors.stamp,
                  size: 20,
                ),
              ),
              const SizedBox(width: SwSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kind.title, style: SwType.subtitle),
                    const SizedBox(height: 2),
                    Text(
                      connector.unavailableReason ?? kind.description,
                      style: SwType.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SwSpace.md),
              if (busy)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (connector.isAvailable)
                AnimatedSlide(
                  duration: duration,
                  offset: state.hovered ? const Offset(0.25, 0) : Offset.zero,
                  child: Icon(
                    SwIcons.chevronRight,
                    color: state.hovered ? SwColors.stamp : SwColors.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WalletConnect pairing: a QR code for Freighter on another device, plus a
/// direct link when Freighter is on this phone.
class _PairingView extends StatelessWidget {
  const _PairingView({super.key, required this.uri});

  final Uri uri;

  bool get _onPhone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final link = Uri.parse(
      'freighterwallet://wc?uri=${Uri.encodeComponent(uri.toString())}',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Approve in Freighter', style: SwType.title),
        const SizedBox(height: SwSpace.sm),
        Text(
          _onPhone
              ? 'Freighter should open with a connection request. If it '
                    "doesn't, open Freighter and scan this code from another "
                    'screen, or copy the link.'
              : 'Open Freighter on your phone, tap the scanner, and point it '
                    'at this code. Then approve the connection on Testnet.',
          style: SwType.bodySmall,
        ),
        const SizedBox(height: SwSpace.xl),
        Center(
          child: Container(
            padding: const EdgeInsets.all(SwSpace.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(SwRadius.panel),
              border: Border.all(color: SwColors.rule),
            ),
            child: QrImageView(
              data: uri.toString(),
              size: 216,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: SwColors.ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: SwColors.ink,
              ),
              semanticsLabel: 'WalletConnect pairing code',
            ),
          ),
        ),
        const SizedBox(height: SwSpace.lg),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: SwSpace.sm),
            Text('Waiting for approval', style: SwType.caption),
          ],
        ),
        const SizedBox(height: SwSpace.xl),
        Wrap(
          spacing: SwSpace.sm,
          runSpacing: SwSpace.sm,
          alignment: WrapAlignment.end,
          children: [
            SwButton(
              label: 'Copy link',
              icon: SwIcons.copy,
              tone: SwButtonTone.quiet,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: uri.toString()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pairing link copied.')),
                  );
                }
              },
            ),
            if (_onPhone)
              SwButton(
                label: 'Open Freighter',
                icon: SwIcons.openApp,
                onPressed: () => openExternal(link),
              ),
            SwButton(
              label: 'Back',
              tone: SwButtonTone.secondary,
              onPressed: () => context.read<WalletBloc>().add(
                const WalletPairingDismissed(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
