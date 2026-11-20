import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/sw_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/key_text.dart';
import '../../../../core/widgets/sw_button.dart';
import '../../../../core/widgets/sw_sheet.dart';
import '../../bloc/payroll_form/payroll_form_bloc.dart';
import '../../data/roster_import.dart';
import '../../domain/pay_cadence.dart';

const _maxShownIssues = 6;

/// Opens the roster import. Resolves with the previewed roster the person
/// chose to use, or null.
Future<ImportedRoster?> showRosterImport(
  BuildContext context, {
  required int payouts,
  required PayCadence cadence,
  String assetLabel = 'XLM',
  int draftEmployees = 1,
}) => showSwSheet<ImportedRoster>(
  context,
  maxWidth: 720,
  builder: (_) => RosterImportSheet(
    payouts: payouts,
    cadence: cadence,
    assetLabel: assetLabel,
    draftEmployees: draftEmployees,
  ),
);

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
              final roster = await showRosterImport(
                context,
                payouts: bloc.state.payouts,
                cadence: bloc.state.cadence,
                assetLabel: bloc.state.assetLabel,
                draftEmployees: bloc.state.recipients.length,
              );
              if (roster != null && !bloc.isClosed) {
                bloc.add(RosterImported(roster));
              }
            },
    );
  }
}

/// Import a team from a spreadsheet: a sample of the exact file to fill in,
/// then the file itself, previewed before it replaces the draft.
/// Mirrors the web app's src/features/payroll/RosterImport.tsx.
class RosterImportSheet extends StatefulWidget {
  const RosterImportSheet({
    super.key,
    required this.payouts,
    this.cadence = PayCadence.month,
    this.assetLabel = 'XLM',
    this.draftEmployees = 1,
  });

  final int payouts;
  final PayCadence cadence;
  final String assetLabel;
  final int draftEmployees;

  @override
  State<RosterImportSheet> createState() => _RosterImportSheetState();
}

class _RosterImportSheetState extends State<RosterImportSheet> {
  final _text = TextEditingController();
  final _textFocus = FocusNode();
  ImportedRoster? _preview;
  List<String> _issues = const [];
  bool _saving = false;

  bool get _validPayouts => widget.payouts >= 1 && widget.payouts <= 50;

  @override
  void dispose() {
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    _preview = null;
    _issues = const [];
  });

  void _fail(Object problem) => setState(() {
    _preview = null;
    _issues = problem is RosterError
        ? problem.issues
        : [problem is FormatException ? problem.message : '$problem'];
  });

  Future<void> _download() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      // The byte-order mark makes Excel read the file as UTF-8.
      final bytes = utf8.encode(
        '﻿${rosterCsvTemplate(widget.payouts, widget.cadence)}',
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save roster template',
        fileName: 'sweldo-roster-template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(bytes),
      );
      if (!kIsWeb && path != null) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Roster template saved.')),
        );
      }
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'The template couldn’t be saved. Use Fill it in here instead.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _fillHere() {
    final sample = rosterCsvTemplate(
      widget.payouts,
      widget.cadence,
      lineEnd: '\n',
    );
    final start = sample.indexOf(rosterPlaceholderPrefix);
    _text.value = TextEditingValue(
      text: sample,
      // Select the first placeholder so pasting a wallet replaces it.
      selection: TextSelection(
        baseOffset: start,
        extentOffset: sample.indexOf(',', start),
      ),
    );
    _changed();
    _textFocus.requestFocus();
  }

  Future<void> _chooseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size > 100000) {
        _fail('Keep the roster under 100 KB.');
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        _fail('This file could not be read. Paste the rows instead.');
        return;
      }
      _text.text = utf8.decode(bytes, allowMalformed: true);
      _changed();
    } catch (error) {
      if (mounted) _fail(error);
    }
  }

  void _check() {
    try {
      final roster = parseRoster(_text.text, widget.payouts);
      setState(() {
        _preview = roster;
        _issues = const [];
      });
    } catch (error) {
      _fail(error);
    }
  }

  void _use() {
    try {
      Navigator.of(context).pop(parseRoster(_text.text, widget.payouts));
    } catch (error) {
      _fail(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payouts = widget.payouts;
    final maxEmployees = _validPayouts ? 100 ~/ payouts : 0;
    final preview = _preview;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Import roster', style: SwType.title)),
            SwIconButton(
              icon: SwIcons.close,
              tooltip: 'Close roster import',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Add your whole team from a spreadsheet. You’ll check every row before it replaces your draft.',
          style: SwType.bodySmall,
        ),
        const SizedBox(height: SwSpace.lg),
        _Step(
          number: 1,
          title: 'Fill in the template',
          subtitle: 'One employee per row, in this column order. Keep row 1 exactly as it is.',
          children: _validPayouts
              ? [
                  _RosterSample(rosterTemplateRows(payouts, widget.cadence)),
                  _Legend(assetLabel: widget.assetLabel, payouts: payouts),
                  // Full-width and stacked on phones, like the web below 480px.
                  LayoutBuilder(
                    builder: (context, box) {
                      final stack = box.maxWidth < 432;
                      final buttons = [
                        SwButton(
                          label: 'Download CSV template',
                          icon: SwIcons.download,
                          tone: SwButtonTone.secondary,
                          loading: _saving,
                          expand: stack,
                          onPressed: _download,
                        ),
                        SwButton(
                          label: 'Fill it in here',
                          icon: SwIcons.fillIn,
                          tone: SwButtonTone.quiet,
                          expand: stack,
                          onPressed: _fillHere,
                        ),
                      ];
                      return stack
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                buttons[0],
                                const SizedBox(height: SwSpace.sm),
                                buttons[1],
                              ],
                            )
                          : Wrap(
                              spacing: SwSpace.sm,
                              runSpacing: SwSpace.sm,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: buttons,
                            );
                    },
                  ),
                ]
              : [
                  Text(
                    'Choose 1–50 payouts in Schedule before importing.',
                    style: SwType.bodySmall.copyWith(color: SwColors.danger),
                  ),
                ],
        ),
        _Step(
          number: 2,
          title: 'Add your file',
          subtitle: 'Choose the CSV you saved, or paste rows straight from your spreadsheet.',
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SwButton(
                label: 'Choose CSV file',
                icon: SwIcons.upload,
                tone: SwButtonTone.secondary,
                onPressed: _chooseFile,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('CSV or pasted rows', style: SwType.label),
                const SizedBox(height: 6),
                TextField(
                  controller: _text,
                  focusNode: _textFocus,
                  minLines: 6,
                  maxLines: 10,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: SwType.mono.copyWith(
                    color: SwColors.ink,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: _validPayouts
                        ? rosterCsvTemplate(
                            payouts,
                            widget.cadence,
                            lineEnd: '\n',
                          ).trimRight()
                        : rosterHeader,
                    hintStyle: SwType.mono.copyWith(
                      color: SwColors.inkFaint,
                      fontSize: 13,
                      height: 1.6,
                    ),
                    hintMaxLines: 3,
                  ),
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_validPayouts ? 'With $payouts payouts each, one import holds up to $maxEmployees ${maxEmployees == 1 ? 'employee' : 'employees'}.' : 'Set your payouts in Schedule first.'} CSV or tab-separated, up to 100 KB.',
                  style: SwType.caption,
                ),
              ],
            ),
            if (_issues.isNotEmpty) _Issues(_issues),
            if (preview != null)
              _Preview(
                roster: preview,
                assetLabel: widget.assetLabel,
                draftEmployees: widget.draftEmployees,
              ),
          ],
        ),
        const SizedBox(height: SwSpace.lg),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: SwSpace.sm,
          runSpacing: SwSpace.sm,
          children: [
            ListenableBuilder(
              listenable: _text,
              builder: (context, _) => SwButton(
                label: 'Preview roster',
                tone: preview == null
                    ? SwButtonTone.primary
                    : SwButtonTone.secondary,
                onPressed: _text.text.trim().isEmpty || !_validPayouts
                    ? null
                    : _check,
              ),
            ),
            if (preview != null) SwButton(label: 'Use roster', onPressed: _use),
          ],
        ),
      ],
    );
  }
}

/// A numbered section of the import, with a rule above it.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final int number;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: SwSpace.lg),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: SwColors.rule)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: SwColors.stampWash,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: SwType.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SwColors.stamp,
                ),
              ),
            ),
            const SizedBox(width: SwSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SwType.subtitle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: SwType.bodySmall),
                ],
              ),
            ),
          ],
        ),
        for (final child in children) ...[
          const SizedBox(height: SwSpace.md),
          child,
        ],
      ],
    ),
  );
}

/// The template as it looks in a spreadsheet: lettered columns, numbered
/// rows, greenbar bands. On a phone the long sample wallet truncates so all
/// four columns stay in view.
class _RosterSample extends StatelessWidget {
  const _RosterSample(this.rows);

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final narrow = box.maxWidth < 560;
      final size = narrow ? 11.0 : 12.0;
      final pad = EdgeInsets.symmetric(
        horizontal: narrow ? 8 : 10,
        vertical: narrow ? 7 : 8,
      );
      const rule = BorderSide(color: SwColors.rule);
      final mono = SwType.mono.copyWith(
        fontSize: size,
        height: 1.4,
        color: SwColors.inkMuted,
      );
      final chrome = SwType.caption.copyWith(
        fontSize: 10,
        color: SwColors.inkFaint,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      );
      Widget cell(
        String text, {
        TextStyle? style,
        Color? color,
        bool first = false,
        bool center = false,
        EdgeInsets? padding,
      }) => Container(
        padding: padding ?? pad,
        alignment: center ? Alignment.center : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color,
          border: first ? null : const Border(left: rule),
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: style ?? mono,
        ),
      );
      return Semantics(
        label: 'Roster template layout',
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: SwColors.sheet,
            border: Border.all(color: SwColors.rule),
            borderRadius: const BorderRadius.all(SwRadius.field),
          ),
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
              2: IntrinsicColumnWidth(),
              3: IntrinsicColumnWidth(),
              4: IntrinsicColumnWidth(),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: SwColors.paper,
                  border: Border(bottom: rule),
                ),
                children: [
                  cell(
                    '',
                    first: true,
                    padding: pad.copyWith(top: 4, bottom: 4),
                  ),
                  for (final letter in ['A', 'B', 'C', 'D'])
                    cell(
                      letter,
                      style: chrome,
                      center: true,
                      padding: pad.copyWith(top: 4, bottom: 4),
                    ),
                ],
              ),
              for (var line = 0; line < rows.length; line++)
                TableRow(
                  decoration: line == 0
                      ? const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: rule),
                        )
                      : null,
                  children: [
                    cell(
                      '${line + 1}',
                      first: true,
                      center: true,
                      color: SwColors.paper,
                      style: chrome.copyWith(fontSize: 11, letterSpacing: 0),
                    ),
                    for (final value in rows[line])
                      cell(
                        value,
                        color: line == 1 ? SwColors.greenbar : null,
                        style: line == 0
                            ? mono.copyWith(
                                color: SwColors.ink,
                                fontWeight: FontWeight.w500,
                              )
                            : value.startsWith(rosterPlaceholderPrefix)
                            ? mono.copyWith(color: SwColors.stamp)
                            : null,
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// What goes in each column, keyed by the sample's column letters.
class _Legend extends StatelessWidget {
  const _Legend({required this.assetLabel, required this.payouts});

  final String assetLabel;
  final int payouts;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'A',
        'wallet',
        'The employee’s public address: 56 characters, starts with G.',
      ),
      (
        'B',
        'name',
        'Optional, up to 80 characters. Quote names with commas: "Santos, Ana".',
      ),
      (
        'C',
        'amount',
        'Total $assetLabel for all $payouts payouts. ${100 * payouts} = 100 a payout.',
      ),
      ('D', 'cadence', 'minute, day, week or month, the same on every row.'),
    ];
    Widget item((String, String, String) entry) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SwColors.paper,
                border: Border.all(color: SwColors.rule),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: Text(
                entry.$1,
                style: SwType.caption.copyWith(
                  fontSize: 10,
                  color: SwColors.inkFaint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              entry.$2,
              style: SwType.mono.copyWith(
                fontSize: 12,
                color: SwColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          entry.$3,
          style: SwType.bodySmall.copyWith(fontSize: 13, height: 1.4),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                item(items[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: item(items[row * 2])),
                  const SizedBox(width: 20),
                  Expanded(child: item(items[row * 2 + 1])),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Every problem at once, so a spreadsheet can be fixed in one pass.
class _Issues extends StatelessWidget {
  const _Issues(this.issues);

  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final shown = issues.take(_maxShownIssues).toList();
    final line = SwType.bodySmall.copyWith(
      color: SwColors.danger,
      fontSize: 13,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SwSpace.lg,
          vertical: SwSpace.md,
        ),
        decoration: const BoxDecoration(
          color: SwColors.dangerWash,
          borderRadius: BorderRadius.all(SwRadius.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(SwIcons.error, size: 16, color: SwColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    issues.length == 1
                        ? 'Fix this, then preview again'
                        : 'Fix these ${issues.length} problems, then preview again',
                    style: SwType.label.copyWith(color: SwColors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final issue in shown)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: line),
                    Expanded(child: Text(issue, style: line)),
                  ],
                ),
              ),
            if (issues.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '…and ${issues.length - shown.length} more.',
                  style: SwType.caption,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.roster,
    required this.assetLabel,
    required this.draftEmployees,
  });

  final ImportedRoster roster;
  final String assetLabel;
  final int draftEmployees;

  @override
  Widget build(BuildContext context) {
    final count = roster.rows.length;
    const rule = BorderSide(color: SwColors.rule);
    final head = SwType.label.copyWith(fontSize: 13, color: SwColors.inkMuted);
    final body = SwType.bodySmall.copyWith(fontSize: 13, color: SwColors.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$count ${count == 1 ? 'employee' : 'employees'} · ${roster.cadence.name} cadence',
          style: SwType.subtitle,
        ),
        const SizedBox(height: 6),
        Text(
          'Choose Use roster to replace the $draftEmployees ${draftEmployees == 1 ? 'employee' : 'employees'} in your draft. You’ll review Schedule and Lock next.',
          style: SwType.bodySmall,
        ),
        const SizedBox(height: SwSpace.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: SingleChildScrollView(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(),
                1: IntrinsicColumnWidth(),
                2: IntrinsicColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(border: Border(bottom: rule)),
                  children: [
                    _cell(Text('Employee', style: head)),
                    _cell(Text('Wallet', style: head)),
                    _cell(Text('Total ($assetLabel)', style: head), end: true),
                  ],
                ),
                for (var i = 0; i < count; i++)
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: rule),
                    ),
                    children: [
                      _cell(
                        Text(
                          roster.rows[i].name.isEmpty
                              ? 'Employee ${i + 1}'
                              : roster.rows[i].name,
                          style: roster.rows[i].name.isEmpty
                              ? body.copyWith(color: SwColors.inkMuted)
                              : body,
                        ),
                      ),
                      _cell(KeyText(roster.rows[i].employee, edge: 4)),
                      _cell(
                        Text(
                          roster.rows[i].total,
                          style: body.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        end: true,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(Widget child, {bool end = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Align(
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    ),
  );
}
