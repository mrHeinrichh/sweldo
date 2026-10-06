import 'package:equatable/equatable.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// test-USDC → PHPT, both issued by controlled Testnet accounts.
class ConversionPair extends Equatable {
  const ConversionPair({required this.source, required this.destination});

  final Asset source;
  final Asset destination;

  AssetTypeCreditAlphaNum get sourceCredit => source as AssetTypeCreditAlphaNum;
  AssetTypeCreditAlphaNum get destinationCredit =>
      destination as AssetTypeCreditAlphaNum;

  String get sourceCanonical => Asset.canonicalForm(source);

  @override
  List<Object?> get props => [
    Asset.canonicalForm(source),
    Asset.canonicalForm(destination),
  ];
}
