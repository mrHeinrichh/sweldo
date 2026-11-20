import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/sw_icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/sw_button.dart';
import '../../features/wallet/bloc/wallet_bloc.dart';
import '../../features/wallet/view/connect_wallet_sheet.dart';
import '../dependencies.dart';

/// The role is chosen before a first-time visitor enters either workflow.
class FirstUseFlow extends StatefulWidget {
  const FirstUseFlow({super.key});

  @override
  State<FirstUseFlow> createState() => _FirstUseFlowState();
}

class _FirstUseFlowState extends State<FirstUseFlow> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    final deps = context.read<AppDependencies>();
    if (deps.config.storyDemo ||
        deps.store.readString('sweldo-role-v1') != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    final role = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.all(SwSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SwSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(SwIcons.team, size: 36, color: SwColors.stamp),
                  const SizedBox(height: SwSpace.lg),
                  Text(
                    'Welcome to Sweldo',
                    textAlign: TextAlign.center,
                    style: SwType.title,
                  ),
                  const SizedBox(height: SwSpace.sm),
                  Text(
                    'Are you an employer or an employee?',
                    textAlign: TextAlign.center,
                    style: SwType.subtitle,
                  ),
                  const SizedBox(height: SwSpace.sm),
                  Text(
                    'Choose where to start. You can switch pages at any time.',
                    textAlign: TextAlign.center,
                    style: SwType.bodySmall,
                  ),
                  const SizedBox(height: SwSpace.xl),
                  SwButton(
                    label: 'I’m an employer',
                    icon: SwIcons.team,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop('employer'),
                  ),
                  const SizedBox(height: SwSpace.sm),
                  Text(
                    'Set up your team, schedule pay and lock payroll.',
                    textAlign: TextAlign.center,
                    style: SwType.caption,
                  ),
                  const SizedBox(height: SwSpace.lg),
                  SwButton(
                    label: 'I’m an employee',
                    icon: SwIcons.wallet,
                    tone: SwButtonTone.secondary,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop('employee'),
                  ),
                  const SizedBox(height: SwSpace.sm),
                  Text(
                    'See your paydays and claim pay into your wallet.',
                    textAlign: TextAlign.center,
                    style: SwType.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || role == null) return;
    final deps = context.read<AppDependencies>();
    await deps.store.writeString('sweldo-role-v1', role);
    if (!mounted) return;
    context.go(role == 'employer' ? '/employer' : '/pay');
    if (context.read<WalletBloc>().state.session != null) return;
    final connect = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(SwSpace.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SwSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(SwIcons.wallet, size: 38, color: SwColors.stamp),
                const SizedBox(height: SwSpace.lg),
                Text(
                  'Wallet not connected',
                  textAlign: TextAlign.center,
                  style: SwType.title,
                ),
                const SizedBox(height: SwSpace.sm),
                Text(
                  'Connect it now to ${role == 'employer' ? 'lock your team’s payroll' : 'see and claim your pay'}. Choose Varial to get started.',
                  textAlign: TextAlign.center,
                  style: SwType.bodySmall,
                ),
                const SizedBox(height: SwSpace.xl),
                SwButton(
                  label: 'Connect wallet now',
                  icon: SwIcons.wallet,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: SwSpace.sm),
                SwButton(
                  label: 'Explore this page first',
                  tone: SwButtonTone.quiet,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted &&
        connect == true &&
        context.read<WalletBloc>().state.session == null) {
      await showConnectWalletSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
