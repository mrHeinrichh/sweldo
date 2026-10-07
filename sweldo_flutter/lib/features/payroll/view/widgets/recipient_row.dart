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
/// every edit to [PayrollFormBloc], and follows values set elsewhere (a new
/// draft).
class RecipientRow extends StatefulWidget {
  const RecipientRow({
    super.key,
    required this.recipient,
    required this.index,
    required this.payouts,
    required this.assetLabel,
    required this.removable,
    required this.animateIn,
    this.teamChecks = 0,
    this.focusOnCheck = false,
  });

  final PayrollRecipient recipient;
  final int index;
  final int payouts;
  final String assetLabel;
  final bool removable;
  final bool animateIn;

  /// Times someone tried to continue with the team incomplete. Above 0, the
  /// required fields show what's missing even if nobody touched them.
  final int teamChecks;

  /// This is the first employee with something missing: take focus when
  /// [teamChecks] goes up.
  final bool focusOnCheck;

  @override
  State<RecipientRow> createState() => _RecipientRowState();
}

class _RecipientRowState extends State<RecipientRow> {
  late final _name = TextEditingController(text: widget.recipient.name);
  late final _address = TextEditingController(text: widget.recipient.employee);
  late final _total = TextEditingController(text: widget.recipient.total);
  final _addressNode = FocusNode();
  final _totalNode = FocusNode();
  bool _addressTouched = false;
  bool _totalTouched = false;

  @override
  void initState() {
    super.initState();
    _addressNode.addListener(() {
      if (!_addressNode.hasFocus) setState(() => _addressTouched = true);
    });
    _totalNode.addListener(() {
      if (!_totalNode.hasFocus) setState(() => _totalTouched = true);
    });
  }

  @override
  void didUpdateWidget(RecipientRow old) {
    super.didUpdateWidget(old);
    // Values can change from outside (a new draft); keep the fields in step
    // without disturbing a field the person is typing in.
    _sync(_name, widget.recipient.name);
    _sync(_address, widget.recipient.employee);
    _sync(_total, widget.recipient.total);
    if (widget.teamChecks != old.teamChecks && widget.focusOnCheck) {
      // Point at the first thing to fix.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final node = widget.recipient.hasValidAddress
            ? _totalNode
            : _addressNode;
        node.requestFocus();
        Scrollable.ensureVisible(
          context,
          alignment: 0.3,
          duration: SwMotion.of(context, SwMotion.standard),
          curve: SwMotion.move,
        );
      });
    }
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
    _addressNode.dispose();
    _totalNode.dispose();
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
    final checking = widget.teamChecks > 0;
    // The wallet address is required: say so once the field is left empty or
    // someone tries to continue without it.
    final String? addressError =
        recipient.hasValidAddress || !(_addressTouched || checking)
        ? null
        : recipient.employee.isEmpty
        ? 'Add this person’s Stellar wallet address.'
        : 'A Stellar public key has 56 characters and starts with G.';
    final totalUnits = Amount.tryUnits(recipient.total) ?? BigInt.zero;
    final String? totalError = !(_totalTouched || checking)
        ? null
        : totalUnits <= BigInt.zero
        ? 'Enter the total pay.'
        : (Amount.tryUnits(perPayout) ?? BigInt.zero) <= BigInt.zero
        ? 'Too small to split into ${widget.payouts} payouts.'
        : null;
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
      hint: 'Required',
      child: TextField(
        controller: _address,
        focusNode: _addressNode,
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
          errorText: addressError,
        ),
        onChanged: (value) => _changed(employee: value),
      ),
    );
    final totalField = _Field(
      label: 'Total pay',
      child: TextField(
        controller: _total,
        focusNode: _totalNode,
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
          errorText: totalError,
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
            // Top-aligned so an error under the total doesn't push the split
            // out of line; the split sits level with the middle of the field.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: totalField),
                const SizedBox(width: SwSpace.lg),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 34),
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

    final Widget row = card;

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
