import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/features/payroll/data/roster_import.dart';
import 'package:sweldo/features/payroll/domain/pay_cadence.dart';

import 'ledger_roster_test.dart' show worker, other;

// The same cases as the web app's scripts/roster-template.test.mjs.

Matcher _issues(List<Matcher> each) =>
    throwsA(isA<RosterError>().having((e) => e.issues, 'issues', each));

void main() {
  test('the template cannot import its placeholders and says which rows', () {
    for (final payouts in [1, 3, 7, 50]) {
      final template = rosterCsvTemplate(payouts, PayCadence.week);
      expect(template.split('\r\n').first, 'wallet,name,amount,cadence');
      expect(
        () => parseRoster(template, payouts),
        _issues([
          startsWith(
            'Row 2: replace REPLACE_WITH_EMPLOYEE_1_G_ADDRESS with the employee’s Stellar wallet address',
          ),
          startsWith(
            'Row 3: replace REPLACE_WITH_EMPLOYEE_2_G_ADDRESS with the employee’s Stellar wallet address',
          ),
        ]),
      );
    }
  });

  test('the on-screen sample and the saved file are the same cells', () {
    final rows = rosterTemplateRows(8, PayCadence.month);
    expect(
      rosterCsvTemplate(8, PayCadence.month),
      '${rows.map((row) => row.join(',')).join('\r\n')}\r\n',
    );
    expect(rows[1].sublist(1), ['Employee 1', '800', 'month']);
    expect(
      rosterCsvTemplate(8, PayCadence.month, lineEnd: '\n'),
      isNot(contains('\r')),
    );
  });

  test(
    'replacing sample wallets imports at every payout count and cadence',
    () {
      for (var payouts = 1; payouts <= 50; payouts++) {
        for (final cadence in PayCadence.values) {
          final text = rosterCsvTemplate(payouts, cadence)
              .replaceFirst('REPLACE_WITH_EMPLOYEE_1_G_ADDRESS', worker)
              .replaceFirst('REPLACE_WITH_EMPLOYEE_2_G_ADDRESS', other);
          final roster = parseRoster(text, payouts);
          expect(roster.cadence, cadence);
          expect(roster.rows.map((row) => row.total), [
            '${payouts * 100}',
            '${payouts * 200}',
          ]);
        }
      }
    },
  );

  test('every broken row is reported at once', () {
    final secret = KeyPair.random().secretSeed;
    final liza = KeyPair.random().accountId;
    final text = [
      rosterHeader,
      '$worker,Ana,800,week',
      '$secret,Marco,800,week',
      '$liza,Liza,1 600 XLM,week',
      '$worker,Ana again,800,week',
      '$other,Marco,800,fortnight',
    ].join('\n');
    expect(
      () => parseRoster(text, 8),
      _issues([
        startsWith('Row 3: this is a secret key'),
        startsWith('Row 4: write the amount as a plain number'),
        startsWith(
          'Row 5: the same wallet appears more than once (also in row 2)',
        ),
        startsWith('Row 6: cadence must be'),
      ]),
    );
  });

  test('spreadsheet habits are accepted: cadence words, grouped amounts, blank names, any column order', () {
    final text = [
      'Name,Cadence,Wallet,Amount',
      'Ana Santos,Weekly,$worker,"1,600"',
      ',every week,$other,"12,000.80"',
    ].join('\r\n');
    final roster = parseRoster(text, 8);
    expect(roster.cadence, PayCadence.week);
    expect(roster.rows.map((row) => [row.name, row.total]), [
      ['Ana Santos', '1600'],
      ['', '12000.8'],
    ]);
    // A decimal comma is never read as a thousands separator.
    expect(
      () => parseRoster('$rosterHeader\n$worker,Ana,"1,5",week', 1),
      throwsA(
        isA<RosterError>().having(
          (e) => e.message,
          'message',
          contains('plain number'),
        ),
      ),
    );
  });

  test('the header problem names what is missing or extra', () {
    expect(
      () => parseRoster('wallet,name,total,cadence\n$worker,Ana,8,week', 1),
      throwsA(
        isA<RosterError>().having(
          (e) => e.message,
          'message',
          contains('missing amount; remove total'),
        ),
      ),
    );
  });

  test('mixed cadences and muxed addresses are explained', () {
    expect(
      () => parseRoster(
        '$rosterHeader\n$worker,Ana,8,daily\n$other,M,8,month',
        1,
      ),
      throwsA(
        isA<RosterError>().having(
          (e) => e.message,
          'message',
          contains('found day and month'),
        ),
      ),
    );
    final muxed = MuxedAccount(worker, BigInt.from(42)).accountId;
    expect(
      () => parseRoster('$rosterHeader\n$muxed,Ana,8,week', 1),
      throwsA(
        isA<RosterError>().having(
          (e) => e.message,
          'message',
          contains('muxed'),
        ),
      ),
    );
  });
}
