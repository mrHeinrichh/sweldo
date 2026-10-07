part of 'payouts_bloc.dart';

sealed class PayoutsEvent {
  const PayoutsEvent();
}

final class PayoutsWalletChanged extends PayoutsEvent {
  const PayoutsWalletChanged(this.session);
  final WalletSession? session;
}

final class PayoutsRefreshRequested extends PayoutsEvent {
  const PayoutsRefreshRequested();
}

final class PayoutClaimRequested extends PayoutsEvent {
  const PayoutClaimRequested(this.payout);
  final Payout payout;
}

final class PayoutConversionCompleted extends PayoutsEvent {
  const PayoutConversionCompleted(this.receipt);
  final ConversionReceipt receipt;
}

final class PayoutsNoticeDismissed extends PayoutsEvent {
  const PayoutsNoticeDismissed();
}
