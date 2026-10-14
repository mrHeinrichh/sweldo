import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/sw_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/sw_button.dart';
import '../../bloc/payroll_form/payroll_form_bloc.dart';
import '../../data/roster_import.dart';

class RosterImportButton extends StatelessWidget {
  const RosterImportButton({super.key});
  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<PayrollFormBloc>();
    return SwButton(
      label: 'Import roster',
      icon: SwIcons.importFile,
      tone: SwButtonTone.quiet,
      onPressed: bloc.state.submitting
          ? null
          : () async {
              final roster = await showDialog<ImportedRoster>(
                context: context,
                builder: (_) => RosterImportDialog(
                  payouts: bloc.state.payouts,
                  assetLabel: bloc.state.assetLabel,
                ),
              );
              if (roster != null && !bloc.isClosed) {
                bloc.add(RosterImported(roster));
              }
            },
    );
  }
}

class RosterImportDialog extends StatefulWidget {
  const RosterImportDialog({
    super.key,
    required this.payouts,
    this.assetLabel = 'XLM',
  });
  final int payouts;
  final String assetLabel;
  @override
  State<RosterImportDialog> createState() => _RosterImportDialogState();
}

class _RosterImportDialogState extends State<RosterImportDialog> {
  final _text = TextEditingController();
  ImportedRoster? _preview;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    try {
      final roster = parseRoster(_text.text, widget.payouts);
      setState(() {
        _preview = roster;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _preview = null;
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> _choose() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size > 100000 || file.bytes == null) {
        throw const FormatException('Choose a readable CSV file under 100 KB.');
      }
      _text.text = utf8.decode(file.bytes!);
      setState(() {
        _preview = null;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Import roster'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total amounts in ${widget.assetLabel} / ${widget.payouts} payouts per employee',
              style: SwType.caption,
            ),
            const SizedBox(height: SwSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: SwButton(
                label: 'Choose CSV',
                icon: SwIcons.importFile,
                tone: SwButtonTone.secondary,
                onPressed: _choose,
              ),
            ),
            const SizedBox(height: SwSpace.md),
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 8,
              style: SwType.mono,
              decoration: const InputDecoration(
                labelText: 'CSV or pasted rows',
                hintText: 'wallet,name,amount,cadence',
              ),
              onChanged: (_) => setState(() {
                _preview = null;
                _error = null;
              }),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: SwSpace.md),
                child: Text(
                  _error!,
                  style: SwType.bodySmall.copyWith(color: SwColors.danger),
                ),
              ),
            if (_preview != null) ...[
              const SizedBox(height: SwSpace.md),
              Text(
                '${_preview!.rows.length} employees / ${_preview!.cadence.name} cadence',
                style: SwType.label,
              ),
              for (final row in _preview!.rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.name.isEmpty ? 'Team member' : row.name),
                  subtitle: Text(
                    '${row.employee.substring(0, 5)}...${row.employee.substring(51)}',
                  ),
                  trailing: Text('${row.total} ${widget.assetLabel}'),
                ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _parse, child: const Text('Preview roster')),
      FilledButton(
        onPressed: _preview == null
            ? null
            : () => Navigator.pop(
                context,
                parseRoster(_text.text, widget.payouts),
              ),
        child: const Text('Use roster'),
      ),
    ],
  );
}
