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
import '../../../core/widgets/operation_progress.dart';
import '../bloc/wallet_bloc.dart';
import '../data/walletconnect/freighter_links.dart';
import '../data/wallet_connector.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_session.dart';
import '../../../core/theme/sw_icons.dart';

/// Opens the wallet picker as a bottom sheet on phones and a dialog on wide
/// screens. Closes itself once a wallet connects.
Future<void> showConnectWalletSheet(BuildContext context) async {
  final bloc = context.read<WalletBloc>();
  final repository = context.read<WalletRepository>();
  final content = ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.82,
    ),
    child: SingleChildScrollView(
      child: BlocProvider.value(
        value: bloc,
        child: _ConnectWalletContent(connectors: repository.connectors),
      ),
    ),
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

class _ConnectWalletContent extends StatefulWidget {
  const _ConnectWalletContent({required this.connectors});

  final List<WalletConnector> connectors;

  @override
  State<_ConnectWalletContent> createState() => _ConnectWalletContentState();
}

class _ConnectWalletContentState extends State<_ConnectWalletContent>
    with WidgetsBindingObserver {
  bool _away = false;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _away = true;
    }
    if (state == AppLifecycleState.resumed && _away) {
      _away = false;
      if (mounted) setState(() => _returned = true);
    }
  }

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pairing == null)
                  _WalletChoices(
                    key: const ValueKey('choices'),
                    connectors: widget.connectors,
                    state: state,
                  )
                else
                  _PairingView(key: ValueKey(pairing), uri: pairing),
                if (state.status == WalletStatus.connecting) ...[
                  const SizedBox(height: SwSpace.lg),
                  OperationProgress(
                    title: _returned
                        ? 'Receiving wallet approval'
                        : 'Connecting your wallet',
                    message: _returned
                        ? 'You’re back. Checking for your wallet’s approval. The connection is complete only when your wallet responds.'
                        : pairing == null
                        ? 'Opening the wallet connection request. Review it in your wallet.'
                        : 'Connection link ready. Approve in Varial, then return to Sweldo.',
                    steps: const [
                      'Request sent',
                      'Wallet approval',
                      'Connected',
                    ],
                    currentStep: pairing == null ? 0 : 1,
                    slowMessage: 'Still waiting for approval. Open your wallet to check the request, or cancel and try connecting again.',
                  ),
                ],
              ],
            ),
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
    final ordered =
        connectors
            .where(
              (c) =>
                  !FreighterLinks.onPhone ||
                  c.kind != WalletKind.freighterExtension,
            )
            .toList()
          ..sort((a, b) {
            int rank(WalletConnector c) => switch (c.kind) {
              WalletKind.freighterExtension => 0,
              WalletKind.freighterMobile => 1,
              WalletKind.xbull => 2,
            };
            return rank(a).compareTo(rank(b));
          });
    final recommended =
        ordered
            .where((c) => c.kind != WalletKind.xbull && c.isAvailable)
            .firstOrNull ??
        ordered.where((c) => c.kind != WalletKind.xbull).firstOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Connect wallet', style: SwType.title),
        const SizedBox(height: SwSpace.sm),
        Text(
          'Your wallet signs each transaction after you review it. Sweldo never '
          'sees your keys.',
          style: SwType.bodySmall,
        ),
        const SizedBox(height: SwSpace.xl),
        for (final connector in ordered) ...[
          _WalletOption(
            connector: connector,
            recommended: identical(connector, recommended),
            busy: state.connectingKind == connector.kind,
            enabled:
                connector.isAvailable &&
                state.status != WalletStatus.connecting,
          ),
          const SizedBox(height: SwSpace.md),
        ],
        if (state.status == WalletStatus.connecting)
          SwButton(
            label: 'Cancel connection',
            onPressed: () =>
                context.read<WalletBloc>().add(const WalletPairingDismissed()),
          ),
        // Only offer the store when Varial is known to be missing.
        _FreighterInstalled(
          builder: (context, installed) => installed == false
              ? Padding(
                  padding: const EdgeInsets.only(top: SwSpace.sm),
                  child: Row(
                    children: [
                      Text("Don't have Varial? ", style: SwType.bodySmall),
                      ExternalLink(
                        label: 'Get it on ${FreighterLinks.storeName}',
                        uri: FreighterLinks.store,
                        style: SwType.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Builds with whether Varial is installed on this phone: null while
/// checking, then true or false. Checks again when Sweldo comes back to the
/// front, so installing Varial from the store updates the sheet.
class _FreighterInstalled extends StatefulWidget {
  const _FreighterInstalled({required this.builder});

  final Widget Function(BuildContext context, bool? installed) builder;

  @override
  State<_FreighterInstalled> createState() => _FreighterInstalledState();
}

class _FreighterInstalledState extends State<_FreighterInstalled>
    with WidgetsBindingObserver {
  bool? _installed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final installed = await FreighterLinks.isInstalled();
    if (mounted && installed != _installed) {
      setState(() => _installed = installed);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _installed);
}

class _WalletOption extends StatelessWidget {
  const _WalletOption({
    required this.connector,
    required this.recommended,
    required this.busy,
    required this.enabled,
  });

  final WalletConnector connector;
  final bool recommended;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final kind = connector.kind;
    final icon = kind == WalletKind.freighterExtension
        ? SwIcons.extension
        : kind == WalletKind.xbull
        ? SwIcons.browser
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
            color: busy || state.hovered || recommended
                ? SwColors.stamp
                : SwColors.rule,
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
                    Text(
                      '${kind.title}${recommended ? ' · Recommended' : ''}',
                      style: SwType.subtitle,
                    ),
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

/// WalletConnect pairing: a QR code for Varial on another device, plus a
/// direct link when Varial is on this phone.
class _PairingView extends StatelessWidget {
  const _PairingView({super.key, required this.uri});

  final Uri uri;

  bool get _onPhone => FreighterLinks.onPhone;

  @override
  Widget build(BuildContext context) {
    final link = FreighterLinks.pair(uri);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Approve in Varial', style: SwType.title),
        const SizedBox(height: SwSpace.sm),
        _FreighterInstalled(
          builder: (context, installed) => Text(
            !_onPhone
                ? 'Open Varial on your phone, tap the scanner, and point it '
                      'at this code. Then approve the connection on Testnet.'
                : installed == false
                ? 'Varial should open with a connection request. If it '
                      "isn't installed, you'll go to ${FreighterLinks.storeName} "
                      'to get it.'
                : 'Varial should open with a connection request.',
            style: SwType.bodySmall,
          ),
        ),
        // On a phone the link opens Varial directly; the code is for
        // scanning from another device.
        if (!_onPhone) ...[
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
        ],
        const SizedBox(height: SwSpace.lg),
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
                label: 'Open Varial',
                icon: SwIcons.openApp,
                onPressed: () => FreighterLinks.open(link),
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
