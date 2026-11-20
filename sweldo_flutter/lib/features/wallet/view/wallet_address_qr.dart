import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/sw_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_sheet.dart';
import 'wallet_qr_parts.dart';

/// The connected wallet's public address as a QR code, for an employer to
/// scan. Mirrors the web app's src/features/wallet/WalletAddressQr.tsx.
Future<void> showWalletAddressQr(BuildContext context, String address) =>
    showSwSheet<void>(
      context,
      maxWidth: 440,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced([
          QrSheetHeading(
            title: 'My wallet QR code',
            closeLabel: 'Close wallet QR code',
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
          Text(
            'Show this to your employer. They scan it to add your wallet to payroll.',
            style: SwType.bodySmall,
          ),
          Container(
            padding: const EdgeInsets.all(SwSpace.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: SwColors.rule),
              borderRadius: const BorderRadius.all(SwRadius.panel),
            ),
            child: Center(
              child: QrImageView(
                data: address,
                size: 248,
                padding: const EdgeInsets.all(8),
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: SwColors.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: SwColors.ink,
                ),
                semanticsLabel: 'QR code of your Stellar public wallet address',
              ),
            ),
          ),
          AddressGroups(address),
          SwButton(
            label: 'Copy wallet address',
            icon: SwIcons.copy,
            tone: SwButtonTone.secondary,
            expand: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: address));
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('Wallet address copied.')),
                );
              }
            },
          ),
          const QrPrivacyNote(
            'This QR shares your public address only. It can’t connect to your wallet or move money.',
          ),
        ]),
      ),
    );

/// Opens [showWalletAddressQr] from a wallet summary, like the web's
/// `WalletQrButton`.
class WalletQrButton extends StatelessWidget {
  const WalletQrButton({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => showWalletAddressQr(context, address),
    icon: const Icon(SwIcons.qrCode, size: 15),
    label: const Text('My wallet QR'),
    style: OutlinedButton.styleFrom(
      foregroundColor: SwColors.stamp,
      backgroundColor: Colors.white,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      side: const BorderSide(color: SwColors.rule),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: SwType.label.copyWith(fontSize: 13),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ).copyWith(overlayColor: const WidgetStatePropertyAll(SwColors.stampWash)),
  );
}
