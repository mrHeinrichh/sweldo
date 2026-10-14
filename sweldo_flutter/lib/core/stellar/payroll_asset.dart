import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class PayrollAssetOption {
  const PayrollAssetOption(this.asset, this.label);

  final Asset asset;
  final String label;
  String get id => Asset.canonicalForm(asset);
  String get code => asset is AssetTypeCreditAlphaNum
      ? (asset as AssetTypeCreditAlphaNum).code
      : 'XLM';
}

List<PayrollAssetOption> payrollAssetOptions(String code, String issuer) => [
  PayrollAssetOption(Asset.NATIVE, 'XLM (Testnet)'),
  if (code == 'USDC' && StrKey.isValidStellarAccountId(issuer))
    PayrollAssetOption(Asset.createNonNativeAsset('USDC', issuer), 'Test-USDC'),
];
