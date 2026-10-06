import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// A claimable balance's claim condition, as Horizon reports it.
sealed class ClaimPredicate {
  const ClaimPredicate();

  factory ClaimPredicate.fromResponse(ClaimantPredicateResponse response) {
    if (response.unconditional == true) return const Unconditional();
    if (response.not != null) {
      return Not(ClaimPredicate.fromResponse(response.not!));
    }
    if (response.and != null) {
      return All(response.and!.map(ClaimPredicate.fromResponse).toList());
    }
    if (response.or != null) {
      return Any(response.or!.map(ClaimPredicate.fromResponse).toList());
    }
    if (response.beforeAbsoluteTime != null) {
      final at = parsePredicateTime(response.beforeAbsoluteTime!);
      if (at != null) return BeforeAbsolute(at);
    }
    if (response.beforeRelativeTime != null) {
      return BeforeRelative(int.tryParse(response.beforeRelativeTime!) ?? 0);
    }
    return const Unsupported();
  }

  /// Whether a claim would pass at [ledgerTime]. Throws for predicates the
  /// app can't evaluate, mirroring `predicateAllows` in the web app.
  bool allows(DateTime ledgerTime) => switch (this) {
    Unconditional() => true,
    Not(:final inner) => !inner.allows(ledgerTime),
    All(:final parts) => parts.every((p) => p.allows(ledgerTime)),
    Any(:final parts) => parts.any((p) => p.allows(ledgerTime)),
    BeforeAbsolute(:final time) => ledgerTime.isBefore(time),
    BeforeRelative() || Unsupported() => throw StateError(
      'This payout predicate is not supported by the conversion flow.',
    ),
  };

  /// Payday for Sweldo's shape: `not(before(payday))`. Null otherwise.
  DateTime? get unlockTime => switch (this) {
    Not(inner: BeforeAbsolute(:final time)) => time,
    _ => null,
  };
}

final class Unconditional extends ClaimPredicate {
  const Unconditional();
}

final class Not extends ClaimPredicate {
  const Not(this.inner);
  final ClaimPredicate inner;
}

final class All extends ClaimPredicate {
  const All(this.parts);
  final List<ClaimPredicate> parts;
}

final class Any extends ClaimPredicate {
  const Any(this.parts);
  final List<ClaimPredicate> parts;
}

final class BeforeAbsolute extends ClaimPredicate {
  const BeforeAbsolute(this.time);
  final DateTime time;
}

final class BeforeRelative extends ClaimPredicate {
  const BeforeRelative(this.seconds);
  final int seconds;
}

final class Unsupported extends ClaimPredicate {
  const Unsupported();
}

/// Horizon sends `abs_before` as ISO-8601; some tools send epoch seconds.
DateTime? parsePredicateTime(String value) {
  final seconds = int.tryParse(value);
  if (seconds != null) {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
  return DateTime.tryParse(value)?.toUtc();
}
