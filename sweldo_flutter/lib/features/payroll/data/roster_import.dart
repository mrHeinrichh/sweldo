import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/utils/amount.dart';
import '../domain/pay_cadence.dart';

// Mirrors the web app's src/lib/roster-import.ts and roster-template.ts:
// the same template, rules and messages.

const rosterColumns = ['wallet', 'name', 'amount', 'cadence'];
final rosterHeader = rosterColumns.join(',');

/// Sample wallets start with this so an unedited template can be recognised
/// and explained.
const rosterPlaceholderPrefix = 'REPLACE_WITH_';

class ImportedRoster {
  const ImportedRoster(this.rows, this.cadence);
  final List<({String employee, String name, String total})> rows;
  final PayCadence cadence;
}

/// Every problem in a roster, one line each, so a spreadsheet can be fixed in
/// one pass.
class RosterError extends FormatException {
  RosterError(this.issues) : super(issues.join('\n'));
  final List<String> issues;
}

Never _fail(String issue) => throw RosterError([issue]);

/// Spreadsheets write cadences in several ways; all of these mean the same
/// schedule.
const _cadenceWords = <String, PayCadence>{
  'minute': PayCadence.minute,
  'minutes': PayCadence.minute,
  'minutely': PayCadence.minute,
  'every minute': PayCadence.minute,
  'day': PayCadence.day,
  'days': PayCadence.day,
  'daily': PayCadence.day,
  'every day': PayCadence.day,
  'week': PayCadence.week,
  'weeks': PayCadence.week,
  'weekly': PayCadence.week,
  'every week': PayCadence.week,
  'month': PayCadence.month,
  'months': PayCadence.month,
  'monthly': PayCadence.month,
  'every month': PayCadence.month,
};

/// Accepts 1600, 1600.50 and spreadsheet grouping like 1,600.50, but never a
/// decimal comma like 1,5.
BigInt _rosterUnits(String value) => Amount.units(
  RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(value)
      ? value.replaceAll(',', '')
      : value,
);

String _headerProblem(List<String> headers) {
  final missing = rosterColumns.where((key) => !headers.contains(key));
  final extra = headers.where((key) => !rosterColumns.contains(key));
  final details = [
    if (missing.isNotEmpty) 'missing ${missing.join(', ')}',
    if (extra.isNotEmpty)
      'remove ${extra.map((key) => key.isEmpty ? '(blank)' : key).join(', ')}',
  ].join('; ');
  return 'Row 1 must be the header $rosterHeader'
      '${details.isEmpty ? '' : ' ($details)'}. '
      'CSV and tab-separated paste are supported.';
}

String? _walletProblem(String wallet) {
  if (wallet.isEmpty) {
    return 'add the employee’s Stellar wallet address (56 characters, starts with G).';
  }
  if (wallet.toUpperCase().startsWith(rosterPlaceholderPrefix)) {
    return 'replace $wallet with the employee’s Stellar wallet address (56 characters, starts with G).';
  }
  if (StrKey.isValidStellarSecretSeed(wallet)) {
    return 'this is a secret key, not a wallet address. Delete it from the file and use the employee’s public address (starts with G).';
  }
  if (StrKey.isValidStellarMuxedAccountId(wallet)) {
    return 'muxed (M…) addresses can’t receive payroll. Use the employee’s main G… address.';
  }
  if (wallet.length != 56 || !StrKey.isValidStellarAccountId(wallet)) {
    return 'enter a valid Stellar G… public key: 56 characters starting with G.';
  }
  return null;
}

/// One roster uses one cadence because the batch engine shares a pay
/// schedule.
ImportedRoster parseRoster(String text, int payouts) {
  if (utf8.encode(text).length > 100000) _fail('Keep the roster under 100 KB.');
  if (payouts < 1 || payouts > 50) {
    _fail('Choose 1-50 payouts before importing.');
  }
  final input = text
      .replaceFirst('﻿', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  final delimiter = input.split('\n').first.contains('\t') ? '\t' : ',';
  late final List<List<String>> parsed;
  try {
    parsed = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
      allowInvalid: false,
    ).convert(input).map((row) => row.map((v) => '$v').toList()).toList();
  } catch (error) {
    _fail(
      'The roster could not be read: ${error is FormatException ? error.message : error}',
    );
  }
  // Blank lines are skipped, like the web importer, so row numbers match.
  final lines = parsed.where((row) => row.any((v) => v.trim().isNotEmpty));
  final head = lines.isEmpty ? const <String>[] : lines.first;
  final data = lines.skip(1).toList();
  final headers = head.map((v) => v.trim().toLowerCase()).toList();
  if (headers.length != rosterColumns.length ||
      rosterColumns.any((key) => !headers.contains(key))) {
    _fail(_headerProblem(headers));
  }
  if (data.isEmpty) _fail('Add at least one employee row below the header.');
  if (data.length * payouts > 100) {
    _fail(
      'This roster needs ${data.length * payouts} operations. Keep employees × payouts at 100 or less: with $payouts payouts, that’s up to ${100 ~/ payouts} employees.',
    );
  }

  final issues = <String>[];
  final rows = <({String employee, String name, String total})>[];
  final firstRowFor = <String, int>{};
  final cadences = <PayCadence>{};
  for (var index = 0; index < data.length; index++) {
    final row = data[index];
    final line = index + 2;
    void problem(String message) => issues.add('Row $line: $message');
    if (row.length != headers.length) {
      problem(
        'expected four columns (${rosterColumns.join(', ')}) but found ${row.length}.',
      );
      continue;
    }
    String cell(String key) => row[headers.indexOf(key)].trim();
    final employee = cell('wallet');
    final name = cell('name');
    final amount = cell('amount');
    final walletIssue = _walletProblem(employee);
    if (walletIssue != null) {
      problem(walletIssue);
      continue;
    }
    final firstRow = firstRowFor[employee];
    if (firstRow != null) {
      problem(
        'the same wallet appears more than once (also in row $firstRow).',
      );
      continue;
    }
    firstRowFor[employee] = line;
    if (name.length > 80) {
      problem('keep the name to 80 characters or fewer.');
      continue;
    }
    late final BigInt units;
    try {
      units = _rosterUnits(amount);
    } on FormatException {
      problem(
        amount.isEmpty ? 'add the total amount for this employee.' : 'write the amount as a plain number like 1600 or 1600.50, with at most seven decimal places and no currency.',
      );
      continue;
    }
    if (units <= BigInt.zero || units % BigInt.from(payouts) != BigInt.zero) {
      problem(
        'amount must be more than 0 and split evenly into $payouts payouts without rounding.',
      );
      continue;
    }
    final cadence =
        _cadenceWords[cell('cadence')
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')];
    if (cadence == null) {
      problem('cadence must be minute, day, week, or month.');
      continue;
    }
    cadences.add(cadence);
    rows.add((employee: employee, name: name, total: Amount.string(units)));
  }
  if (cadences.length > 1) {
    issues.add(
      'Use one cadence for the whole roster (found ${cadences.map((c) => c.name).join(' and ')}). Import different cadences as separate batches.',
    );
  }
  if (issues.isNotEmpty) throw RosterError(issues);
  return ImportedRoster(rows, cadences.first);
}

/// The template as cells: row 1 is the header, then two sample employees paid
/// 100 and 200 per payout. The on-screen sample and the saved file both come
/// from here, so they always match.
List<List<String>> rosterTemplateRows(int payouts, PayCadence cadence) {
  if (payouts < 1 || payouts > 50) {
    throw ArgumentError.value(
      payouts,
      'payouts',
      'Choose 1-50 payouts before downloading a roster template.',
    );
  }
  return [
    [...rosterColumns],
    [
      '${rosterPlaceholderPrefix}EMPLOYEE_1_G_ADDRESS',
      'Employee 1',
      '${100 * payouts}',
      cadence.name,
    ],
    [
      '${rosterPlaceholderPrefix}EMPLOYEE_2_G_ADDRESS',
      'Employee 2',
      '${200 * payouts}',
      cadence.name,
    ],
  ];
}

/// Sample wallets are intentionally invalid until replaced with employees'
/// public keys. [lineEnd] is `\r\n` for the saved file, as spreadsheets
/// expect, and `\n` for the text box.
String rosterCsvTemplate(
  int payouts,
  PayCadence cadence, {
  String lineEnd = '\r\n',
}) => [
  ...rosterTemplateRows(payouts, cadence).map((row) => row.join(',')),
  '',
].join(lineEnd);
