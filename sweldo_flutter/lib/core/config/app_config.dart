import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../features/conversion/domain/conversion_pair.dart';
import '../stellar/payroll_asset.dart';

/// Build-time configuration, supplied with `--dart-define-from-file`.
///
/// Mirrors the React app's `VITE_*` variables:
/// leave the asset fields blank to run the zero-setup XLM demo.
class AppConfig {
  const AppConfig({
    this.assetCode = '',
    this.assetIssuer = '',
    this.phptIssuer = '',
    this.registryContractId = '',
    this.walletConnectProjectId = '',
    this.storyDemo = false,
    this.testFaucetUrl = '',
  });

  factory AppConfig.fromEnvironment() => AppConfig(
    assetCode: const String.fromEnvironment('SWELDO_ASSET_CODE').trim(),
    assetIssuer: const String.fromEnvironment('SWELDO_ASSET_ISSUER').trim(),
    phptIssuer: const String.fromEnvironment('SWELDO_PHPT_ISSUER').trim(),
    registryContractId: const String.fromEnvironment(
      'SWELDO_REGISTRY_CONTRACT_ID',
    ).trim(),
    walletConnectProjectId: const String.fromEnvironment(
      'WALLETCONNECT_PROJECT_ID',
    ).trim(),
    storyDemo: const bool.fromEnvironment('SWELDO_STORY_DEMO'),
    testFaucetUrl: const String.fromEnvironment(
      'SWELDO_TEST_FAUCET_URL',
    ).trim(),
  );

  final String assetCode;
  final String assetIssuer;
  final String phptIssuer;
  final String registryContractId;
  final String walletConnectProjectId;
  final String testFaucetUrl;

  /// Presentation mode: open on the story and play it straight away.
  final bool storyDemo;

  bool get usesIssuedAsset => assetCode.isNotEmpty && assetIssuer.isNotEmpty;

  List<PayrollAssetOption> get payrollAssets =>
      payrollAssetOptions(assetCode, assetIssuer);

  /// Configuration enables Test-USDC; a new session still starts with XLM.
  Asset get payrollAsset => Asset.NATIVE;
  String get assetLabel => 'XLM';

  bool get hasRegistry => registryContractId.isNotEmpty;

  bool get walletConnectEnabled => walletConnectProjectId.isNotEmpty;

  /// Claim-and-convert is only offered for the controlled test-USDC issuer
  /// paired with the controlled PHPT issuer.
  ConversionPair? get conversionPair {
    if (assetCode != 'USDC' || assetIssuer.isEmpty || phptIssuer.isEmpty) {
      return null;
    }
    return ConversionPair(
      source: Asset.createNonNativeAsset('USDC', assetIssuer),
      destination: Asset.createNonNativeAsset('PHPT', phptIssuer),
    );
  }
}
