import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/motion/interactive.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/sw_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../bloc/payroll_form/payroll_form_bloc.dart';
import '../../domain/payroll_recipient.dart';

/// One employee in the payroll form. Owns its text controllers, reports
/// every edit to [PayrollFormBloc], and follows values rolled by Shuffle.
class RecipientRow extends StatefulWidget {
  const RecipientRow({
    super.key,
    required this.recipient,
    required this.index,
    required this.payouts,
    required this.assetLabel,
    required this.removable,
    required this.animateIn,
    required this.shuffles,
  });

  final PayrollRecipient recipient;
  final int index;
  final int payouts;
  final String assetLabel;
  final bool removable;
  final bool animateIn;

  /// Shuffle count; a change flashes the row to show what rolled.
  final int shuffles;

  @override
  State<RecipientRow> createState() => _RecipientRowState();
}

class _RecipientRowState extends State<RecipientRow> {
  late final _name = TextEditingController(text: widget.recipient.name);
  late final _address = TextEditingController(text: widget.recipient.employee);
  late final _total = TextEditingController(text: widget.recipient.total);
  bool _addressTouched = false;

  @override
  void didUpdateWidget(RecipientRow old) {
    super.didUpdateWidget(old);
    // Values can change from outside (Shuffle); keep the fields in step
    // without disturbing a field the person is typing in.
    _sync(_name, widget.recipient.name);
    _sync(_address, widget.recipient.employee);
    _sync(_total, widget.recipient.total);
  }

  void _sync(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _total.dispose();
    super.dispose();
  }

  void _changed({String? name, String? employee, String? total}) {
    context.read<PayrollFormBloc>().add(
      RecipientChanged(
        widget.recipient.id,
        name: name,
        employee: employee,
        total: total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipient = widget.recipient;
    final perPayout = Amount.perPayout(recipient.total, widget.payouts);
    final showAddressError =
        _addressTouched &&
        recipient.employee.isNotEmpty &&
        !recipient.hasValidAddress;
    final twoColumns = context.up(Breakpoint.md);

    final nameField = _Field(
      label: 'Name',
      hint: 'Optional',
      child: TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'e.g. Ana Santos',
          prefixIcon: _FieldIcon(SwIcons.person),
        ),
        onChanged: (value) => _changed(name: value),
      ),
    );
    final addressField = _Field(
      label: 'Wallet address',
      child: Focus(
        onFocusChange: (focused) {
          if (!focused) setState(() => _addressTouched = true);
        },
        child: TextField(
          controller: _address,
          style: SwType.mono.copyWith(color: SwColors.ink, fontSize: 14),
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
            UpperCaseTextFormatter(),
          ],
          decoration: InputDecoration(
            hintText: 'G…',
            prefixIcon: _FieldIcon(
              recipient.hasValidAddress ? SwIcons.check : SwIcons.key,
              color: recipient.hasValidAddress ? SwColors.payday : null,
            ),
            errorText: showAddressError
                ? 'A Stellar public key has 56 characters and starts with G.'
                : null,
          ),
          onChanged: (value) => _changed(employee: value),
        ),
      ),
    );
    final totalField = _Field(
      label: 'Total pay',
      child: TextField(
        controller: _total,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        style: SwType.figures.copyWith(fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const _FieldIcon(SwIcons.amount),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: SwSpace.md),
            child: Text(
              widget.assetLabel,
              style: SwType.label.copyWith(color: SwColors.inkMuted),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
        onChanged: (value) => _changed(total: value),
      ),
    );

    final split = Row(
      children: [
        const Icon(SwIcons.payday, size: 16, color: SwColors.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: AnimatedSwitcher(
            duration: SwMotion.of(context, SwMotion.quick),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              key: ValueKey('$perPayout/${widget.payouts}'),
              perPayout == '0'
                  ? 'Enter an amount to split'
                  : '${widget.payouts} ${plural(widget.payouts, 'payout')} '
                        'of ${Amount.format(perPayout)} ${widget.assetLabel}',
              style: SwType.bodySmall,
            ),
          ),
        ),
      ],
    );

    final card = Container(
      padding: EdgeInsets.all(context.responsive(SwSpace.md, sm: SwSpace.lg)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(SwRadius.panel),
        border: Border.all(color: SwColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(name: recipient.name, index: widget.index),
              const SizedBox(width: SwSpace.md),
              Expanded(
                child: Text(
                  recipient.name.trim().isEmpty
                      ? 'Employee ${widget.index + 1}'
                      : recipient.name.trim(),
                  style: SwType.subtitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.removable)
                Interactive(
                  onTap: () => context.read<PayrollFormBloc>().add(
                    RecipientRemoved(recipient.id),
                  ),
                  tooltip: 'Remove employee ${widget.index + 1}',
                  lift: 0,
                  hoverShadow: false,
                  radius: const BorderRadius.all(Radius.circular(8)),
                  builder: (context, state) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: state.hovered
                          ? SwColors.dangerWash
                          : Colors.transparent,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Icon(
                      SwIcons.close,
                      size: 16,
                      color: state.hovered
                          ? SwColors.danger
                          : SwColors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SwSpace.md),
          if (twoColumns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: nameField),
                const SizedBox(width: SwSpace.md),
                Expanded(flex: 7, child: addressField),
              ],
            )
          else ...[
            nameField,
            const SizedBox(height: SwSpace.md),
            addressField,
          ],
          const SizedBox(height: SwSpace.md),
          if (twoColumns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: totalField),
                const SizedBox(width: SwSpace.lg),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: split,
                  ),
                ),
              ],
            )
          else ...[
            totalField,
            const SizedBox(height: SwSpace.sm),
            split,
          ],
        ],
      ),
    );

    // Flash a violet wash over the row when Shuffle rolls new values.
    Widget row = TweenAnimationBuilder<double>(
      key: ValueKey(widget.shuffles),
      tween: Tween(begin: 1, end: 0),
      duration: SwMotion.of(context, const Duration(milliseconds: 900)),
      curve: Curves.easeOut,
      builder: (context, t, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(SwRadius.panel),
          border: Border.all(
            color: SwColors.stamp.withValues(alpha: 0.7 * t),
            width: 1.5,
          ),
          color: SwColors.stampWash.withValues(alpha: 0.45 * t),
        ),
        child: child,
      ),
      child: card,
    );

    if (!widget.animateIn || SwMotion.reduced(context)) return row;
    return row
        .animate()
        .fadeIn(duration: SwMotion.standard, curve: SwMotion.enter)
        .slideY(
          begin: -0.06,
          end: 0,
          duration: SwMotion.standard,
          curve: SwMotion.enter,
        );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.index});

  final String name;
  final int index;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return AnimatedSwitcher(
      duration: SwMotion.of(context, SwMotion.standard),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Container(
        key: ValueKey(trimmed.isEmpty ? '' : trimmed[0].toUpperCase()),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: SwColors.stampWash,
          shape: BoxShape.circle,
        ),
        child: trimmed.isEmpty
            ? const Icon(SwIcons.person, size: 16, color: SwColors.stamp)
            : Text(
                trimmed.substring(0, 1).toUpperCase(),
                style: SwType.label.copyWith(color: SwColors.stampDeep),
              ),
      ),
    );
  }
}

class _FieldIcon extends StatelessWidget {
  const _FieldIcon(this.icon, {this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 18, color: color ?? SwColors.inkFaint);
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: SwType.label),
            if (hint != null) ...[
              const SizedBox(width: 6),
              Text(hint!, style: SwType.caption),
            ],
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
