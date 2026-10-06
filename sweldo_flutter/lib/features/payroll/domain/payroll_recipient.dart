import 'package:equatable/equatable.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// One row of the payroll form.
class PayrollRecipient extends Equatable {
  const PayrollRecipient({
    required this.id,
    this.name = '',
    this.employee = '',
    this.total = '',
  });

  final String id;
  final String name;

  /// The employee's Stellar public key (G…).
  final String employee;

  /// Total to lock for this person, split evenly across payouts.
  final String total;

  bool get hasValidAddress =>
      employee.length == 56 && StrKey.isValidStellarAccountId(employee);

  PayrollRecipient copyWith({String? name, String? employee, String? total}) =>
      PayrollRecipient(
        id: id,
        name: name ?? this.name,
        employee: employee ?? this.employee,
        total: total ?? this.total,
      );

  @override
  List<Object?> get props => [id, name, employee, total];
}
