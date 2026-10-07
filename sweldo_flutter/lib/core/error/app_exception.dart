/// Typed failures that the UI can translate into direct, actionable copy.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A plain, already user-readable failure.
class UserFacingException extends AppException {
  const UserFacingException(super.message);
}

/// Horizon answered 404 for an account or a ledger entry.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Not found on Stellar Testnet.']);
}

/// Horizon rejected a submitted transaction with result codes.
class StellarRejectedException extends AppException {
  const StellarRejectedException({
    this.transactionCode,
    this.operationCodes = const [],
  }) : super('Stellar rejected the transaction.');

  final String? transactionCode;
  final List<String> operationCodes;

  List<String> get allCodes => [
    ?transactionCode,
    ...operationCodes.where((c) => c != 'op_success'),
  ];
}

/// The transaction left the device but its confirmation never came back.
class SubmissionUncertainException extends AppException {
  const SubmissionUncertainException(this.transactionHash)
    : super(
        'Submission confirmation is unavailable. Check this transaction '
        'on Stellar Expert before retrying.',
      );

  final String transactionHash;
}

/// The wallet is missing, locked, or refused the request.
class WalletException extends AppException {
  const WalletException(super.message, {this.walletMissing = false});

  /// True when no Freighter extension could be reached at all.
  final bool walletMissing;
}
