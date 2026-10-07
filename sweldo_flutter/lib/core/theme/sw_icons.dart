import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's icon vocabulary, drawn from Lucide — the same set the React app
/// uses through lucide-react — so both clients speak with one visual voice.
/// Name icons by what they mean in Sweldo, not by what they look like.
abstract final class SwIcons {
  // Navigation
  static const IconData overview = LucideIcons.house;
  static const IconData team = LucideIcons.usersRound;
  static const IconData myPay = LucideIcons.wallet;
  static const IconData story = LucideIcons.circlePlay;

  // Money and the ledger
  static const IconData wallet = LucideIcons.wallet;
  static const IconData locked = LucideIcons.lockKeyhole;
  static const IconData unlocked = LucideIcons.lockOpen;
  static const IconData payday = LucideIcons.calendarClock;
  static const IconData amount = LucideIcons.coins;
  static const IconData banknote = LucideIcons.banknote;
  static const IconData convert = LucideIcons.arrowRightLeft;
  static const IconData ledger = LucideIcons.layers;
  static const IconData claim = LucideIcons.handCoins;
  static const IconData stamp = LucideIcons.stamp;
  static const IconData receipt = LucideIcons.receiptText;
  static const IconData protectedPay = LucideIcons.shieldCheck;
  static const IconData savings = LucideIcons.piggyBank;
  static const IconData trustline = LucideIcons.link;
  static const IconData sign = LucideIcons.penLine;
  static const IconData person = LucideIcons.userRound;
  static const IconData key = LucideIcons.keyRound;

  // Cadence
  static const IconData everyMinute = LucideIcons.zap;
  static const IconData daily = LucideIcons.sun;
  static const IconData weekly = LucideIcons.calendarRange;
  static const IconData monthly = LucideIcons.calendarDays;
  static const IconData timer = LucideIcons.timer;
  static const IconData hourglass = LucideIcons.hourglass;

  // Actions
  static const IconData add = LucideIcons.plus;
  static const IconData remove = LucideIcons.minus;
  static const IconData close = LucideIcons.x;
  static const IconData check = LucideIcons.check;
  static const IconData copy = LucideIcons.copy;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData replay = LucideIcons.rotateCcw;
  static const IconData undo = LucideIcons.undo2;
  static const IconData external = LucideIcons.arrowUpRight;
  static const IconData openApp = LucideIcons.squareArrowOutUpRight;
  static const IconData logout = LucideIcons.logOut;
  static const IconData play = LucideIcons.play;
  static const IconData pause = LucideIcons.pause;
  static const IconData next = LucideIcons.skipForward;
  static const IconData previous = LucideIcons.skipBack;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData arrowDown = LucideIcons.arrowDown;
  static const IconData grip = LucideIcons.gripVertical;
  static const IconData guide = LucideIcons.compass;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData forward = LucideIcons.arrowRight;
  static const IconData pointer = LucideIcons.pointer;

  // Wallets and devices
  static const IconData extension = LucideIcons.puzzle;
  static const IconData phone = LucideIcons.smartphone;
  static const IconData signal = LucideIcons.signal;
  static const IconData wifi = LucideIcons.wifi;

  // Feedback
  static const IconData success = LucideIcons.circleCheck;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData info = LucideIcons.info;
}
