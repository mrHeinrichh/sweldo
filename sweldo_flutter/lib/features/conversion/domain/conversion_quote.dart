import 'package:equatable/equatable.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Quotes live for one minute, like the web app.
const quoteLifetime = Duration(seconds: 60);

class ConversionQuote extends Equatable {
  const ConversionQuote({
    required this.address,
    required this.balanceId,
    required this.source,
    required this.destination,
    required this.sendAmount,
    required this.expectedAmount,
    required this.minimumAmount,
    required this.path,
    required this.missingTrustlines,
    required this.expiresAt,
  });

  final String address;
  final String balanceId;
  final AssetTypeCreditAlphaNum source;
  final AssetTypeCreditAlphaNum destination;
  final String sendAmount;
  final String expectedAmount;
  final String minimumAmount;
  final List<Asset> path;
  final List<AssetTypeCreditAlphaNum> missingTrustlines;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  List<Object?> get props => [
    address,
    balanceId,
    sendAmount,
    expectedAmount,
    minimumAmount,
    missingTrustlines.map((a) => a.code).toList(),
    expiresAt,
  ];
}

class ConversionReceipt extends Equatable {
  const ConversionReceipt({
    required this.hash,
    required this.balanceId,
    required this.sentAmount,
    required this.receivedAmount,
    required this.minimumAmount,
  });

  final String hash;
  final String balanceId;
  final String sentAmount;

  /// Null when Horizon hadn't indexed the path payment yet; the hash is the
  /// authoritative receipt either way.
  final String? receivedAmount;
  final String minimumAmount;

  @override
  List<Object?> get props => [
    hash,
    balanceId,
    sentAmount,
    receivedAmount,
    minimumAmount,
  ];
}
