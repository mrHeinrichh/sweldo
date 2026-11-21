import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/motion/effects.dart';
import '../../../core/stellar/stellar_network.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// The ledger Sweldo writes to, closing in real time. One true number that
/// keeps moving: it says the network holding everyone's pay is alive right
/// now. It claims nothing about Sweldo's own traffic, and shows nothing at
/// all when Horizon can't be reached.
class LedgerPulse extends StatefulWidget {
  const LedgerPulse({super.key, this.client});

  final http.Client? client;

  @override
  State<LedgerPulse> createState() => _LedgerPulseState();
}

class _LedgerPulseState extends State<LedgerPulse> {
  static final _number = NumberFormat.decimalPattern();

  late final http.Client _http = widget.client ?? http.Client();
  Timer? _poll;
  Timer? _tick;
  int? _sequence;
  DateTime? _closedAt;
  int _age = 0;

  @override
  void initState() {
    super.initState();
    _read();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final closed = _closedAt;
      if (closed == null) return;
      final age = DateTime.now().difference(closed).inSeconds;
      if (age != _age && mounted) setState(() => _age = age < 0 ? 0 : age);
    });
  }

  Future<void> _read() async {
    try {
      final response = await _http
          .get(
            Uri.parse(
              '${StellarNetwork.horizonUrl}/ledgers?order=desc&limit=1',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final embedded = body['_embedded'] as Map<String, dynamic>?;
        final records = embedded?['records'] as List<dynamic>?;
        final record = (records?.isNotEmpty ?? false)
            ? records!.first as Map<String, dynamic>
            : null;
        if (record != null && mounted) {
          setState(() {
            _sequence = (record['sequence'] as num).toInt();
            _closedAt = DateTime.parse(record['closed_at'] as String);
          });
        }
      }
    } catch (_) {
      // Offline, or Horizon is down: the hero simply doesn't show a pulse.
    }
    if (mounted) {
      _poll = Timer(const Duration(seconds: 5), _read);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    if (widget.client == null) _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sequence = _sequence;
    if (sequence == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PingDot(size: 7),
        const SizedBox(width: SwSpace.sm),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Stellar Testnet ledger '),
                TextSpan(
                  text: _number.format(sequence),
                  style: SwType.caption.copyWith(
                    color: SwColors.ink,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: _age < 1 ? ' closed just now' : ' closed ${_age}s ago',
                ),
              ],
            ),
            style: SwType.caption.copyWith(color: SwColors.inkMuted),
          ),
        ),
      ],
    );
  }
}
