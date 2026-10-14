import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import '../../../core/utils/amount.dart';
import '../domain/pay_cadence.dart';

class ImportedRoster {
  const ImportedRoster(this.rows, this.cadence);
  final List<({String employee, String name, String total})> rows;
  final PayCadence cadence;
}

ImportedRoster parseRoster(String text, int payouts) {
  if (utf8.encode(text).length > 100000) {
    throw const FormatException('CSV import is limited to 100 KB.');
  }
  if (payouts < 1 || payouts > 50) {
    throw const FormatException('Use 1-50 payouts per employee.');
  }
  final input = text
      .replaceFirst('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  final delimiter = input.split('\n').first.contains('\t') ? '\t' : ',';
  final parsed = CsvToListConverter(
    fieldDelimiter: delimiter,
    eol: '\n',
    shouldParseNumbers: false,
    allowInvalid: false,
  ).convert(input);
  if (parsed.isEmpty ||
      parsed.first.map((v) => '$v'.trim().toLowerCase()).join(',') !=
          'wallet,name,amount,cadence') {
    throw const FormatException(
      'CSV header must be wallet,name,amount,cadence.',
    );
  }
  final rows = <({String employee, String name, String total})>[];
  final wallets = <String>{};
  PayCadence? cadence;
  for (var i = 1; i < parsed.length; i++) {
    final columns = parsed[i].map((v) => '$v'.trim()).toList();
    if (columns.every((v) => v.isEmpty)) continue;
    if (columns.length != 4) {
      throw FormatException('Row ${i + 1}: use four columns.');
    }
    final employee = columns[0];
    if (employee.length != 56 || !StrKey.isValidStellarAccountId(employee)) {
      throw FormatException('Row ${i + 1}: enter a valid public G wallet key.');
    }
    if (!wallets.add(employee)) {
      throw FormatException(
        'Row ${i + 1}: the same wallet appears more than once.',
      );
    }
    final total = Amount.units(columns[2]);
    if (total <= BigInt.zero || total % BigInt.from(payouts) != BigInt.zero) {
      throw FormatException(
        'Row ${i + 1}: amount must be positive and split evenly into $payouts payouts.',
      );
    }
    final selected = PayCadence.values
        .where((v) => v.name == columns[3].toLowerCase())
        .firstOrNull;
    if (selected == null) {
      throw FormatException(
        'Row ${i + 1}: cadence must be minute, day, week or month.',
      );
    }
    if (cadence != null && cadence != selected) {
      throw const FormatException('Use one cadence per batch.');
    }
    cadence = selected;
    rows.add((
      employee: employee,
      name: columns[1],
      total: Amount.string(total),
    ));
  }
  if (rows.isEmpty) throw const FormatException('Import at least one worker.');
  if (rows.length * payouts > 100) {
    throw FormatException(
      'This roster creates ${rows.length * payouts} operations; the limit is 100.',
    );
  }
  return ImportedRoster(rows, cadence!);
}
