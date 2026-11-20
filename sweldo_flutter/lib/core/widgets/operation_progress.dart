import 'dart:async';

import 'package:flutter/material.dart';

import '../stellar/transaction_activity.dart';
import '../theme/sw_icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// An honest stage checklist with continuous activity and time already spent.
class OperationProgress extends StatefulWidget {
  const OperationProgress({
    super.key,
    required this.title,
    required this.message,
    required this.steps,
    required this.currentStep,
    this.startedAt,
    this.slowMessage,
  });

  final String title;
  final String message;
  final List<String> steps;
  final int currentStep;
  final DateTime? startedAt;
  final String? slowMessage;

  @override
  State<OperationProgress> createState() => _OperationProgressState();
}

class _OperationProgressState extends State<OperationProgress> {
  late final DateTime _started = DateTime.now();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = DateTime.now()
        .difference(widget.startedAt ?? _started)
        .inSeconds;
    final elapsed = seconds < 60
        ? '${seconds}s elapsed'
        : '${seconds ~/ 60}m ${seconds % 60}s elapsed';
    return Container(
      padding: const EdgeInsets.all(SwSpace.lg),
      decoration: BoxDecoration(
        color: SwColors.stampWash,
        borderRadius: const BorderRadius.all(SwRadius.panel),
        border: Border.all(color: SwColors.stamp.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: SwSpace.md),
              Expanded(child: Text(widget.title, style: SwType.subtitle)),
            ],
          ),
          const SizedBox(height: SwSpace.sm),
          Semantics(
            liveRegion: true,
            child: Text(widget.message, style: SwType.bodySmall),
          ),
          const SizedBox(height: SwSpace.md),
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: SwSpace.md),
          Wrap(
            spacing: SwSpace.md,
            runSpacing: SwSpace.sm,
            children: [
              for (var i = 0; i < widget.steps.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      i < widget.currentStep
                          ? SwIcons.check
                          : i == widget.currentStep
                          ? SwIcons.timer
                          : Icons.circle_outlined,
                      size: 14,
                      color: i < widget.currentStep
                          ? SwColors.payday
                          : i == widget.currentStep
                          ? SwColors.stamp
                          : SwColors.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.steps[i],
                      style: SwType.caption.copyWith(
                        color: i <= widget.currentStep
                            ? SwColors.ink
                            : SwColors.inkMuted,
                        fontWeight: i == widget.currentStep
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: SwSpace.sm),
          Text(
            '$elapsed · ${widget.currentStep} of ${widget.steps.length} steps complete',
            style: SwType.caption,
          ),
          if (seconds >= 25 && widget.slowMessage != null) ...[
            const SizedBox(height: SwSpace.sm),
            Text(
              widget.slowMessage!,
              style: SwType.caption.copyWith(color: SwColors.ink),
            ),
          ],
        ],
      ),
    );
  }
}

class TransactionActivityView extends StatelessWidget {
  const TransactionActivityView({super.key, required this.activity});

  final TransactionActivity activity;

  @override
  Widget build(BuildContext context) => OperationProgress(
    key: ValueKey(activity.startedAt),
    title: 'Your transaction is in progress',
    message: switch (activity.stage) {
      TransactionStage.preparing =>
        'Preparing your transaction and checking the wallet.',
      TransactionStage.approval =>
        activity.returnedFromWallet
            ? 'You’re back. Receiving the wallet approval and verifying your signature…'
            : 'Review and approve the request in your wallet. Return here when you finish.',
      TransactionStage.submitting =>
        'Wallet approved. Your transaction is being processed by Stellar.',
      TransactionStage.confirming =>
        'Stellar confirmed your transaction. Preparing the receipt.',
    },
    startedAt: activity.startedAt,
    steps: const [
      'Prepared',
      'Wallet approval',
      'Stellar confirmation',
      'Receipt',
    ],
    currentStep: activity.stage.index,
    slowMessage: activity.stage == TransactionStage.approval
        ? 'Still waiting for the wallet response. Check the approval request in your wallet; do not approve it twice.'
        : 'Stellar is still responding. Keep this page open while we check the result.',
  );
}
