import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_messages.dart';
import '../data/conversion_repository.dart';
import '../domain/conversion_pair.dart';
import '../domain/conversion_quote.dart';

sealed class ConversionEvent {
  const ConversionEvent();
}

final class ConversionQuoteRequested extends ConversionEvent {
  const ConversionQuoteRequested();
}

final class ConversionConfirmed extends ConversionEvent {
  const ConversionConfirmed();
}

class ConversionState extends Equatable {
  const ConversionState({
    this.quote,
    this.loading = false,
    this.signing = false,
    this.error,
    this.uncertainHash,
    this.receipt,
  });

  final ConversionQuote? quote;
  final bool loading;
  final bool signing;
  final String? error;

  /// The transaction may have landed; the person must check before retrying.
  final String? uncertainHash;
  final ConversionReceipt? receipt;

  bool get locked => uncertainHash != null;

  @override
  List<Object?> get props => [
    quote,
    loading,
    signing,
    error,
    uncertainHash,
    receipt,
  ];
}

/// One claim-and-convert dialog: quote, refresh, sign.
class ConversionBloc extends Bloc<ConversionEvent, ConversionState> {
  ConversionBloc({
    required ConversionRepository repository,
    required this.address,
    required this.balanceId,
    required this.pair,
    DateTime Function()? clock,
  }) : _repository = repository,
       _now = clock ?? DateTime.now,
       super(const ConversionState(loading: true)) {
    on<ConversionQuoteRequested>(_onQuoteRequested);
    on<ConversionConfirmed>(_onConfirmed);
  }

  final ConversionRepository _repository;
  final String address;
  final String balanceId;
  final ConversionPair pair;
  final DateTime Function() _now;
  int _request = 0;

  Future<void> _onQuoteRequested(
    ConversionQuoteRequested event,
    Emitter<ConversionState> emit,
  ) async {
    if (state.signing || state.locked) return;
    final id = ++_request;
    emit(const ConversionState(loading: true));
    try {
      final quote = await _repository.quote(
        address: address,
        balanceId: balanceId,
        pair: pair,
      );
      if (id == _request) emit(ConversionState(quote: quote));
    } catch (error) {
      if (id == _request) {
        emit(ConversionState(error: conversionError(error)));
      }
    }
  }

  Future<void> _onConfirmed(
    ConversionConfirmed event,
    Emitter<ConversionState> emit,
  ) async {
    final quote = state.quote;
    if (quote == null || state.signing || quote.isExpired(_now())) return;
    emit(ConversionState(quote: quote, signing: true));
    try {
      final receipt = await _repository.claimAndConvert(quote);
      emit(ConversionState(receipt: receipt));
    } on SubmissionUncertainException catch (error) {
      emit(
        ConversionState(
          error: conversionError(error),
          uncertainHash: error.transactionHash,
        ),
      );
    } catch (error) {
      emit(ConversionState(error: conversionError(error)));
    }
  }
}
