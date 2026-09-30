import 'package:equatable/equatable.dart';

enum DeliveryOutcome { delivered, failed }

/// Why a stop was not delivered.
enum FailureReason { recipientAbsent, addressNotFound, refused, other }

/// What happened at a stop: delivered, or not delivered with a [reason].
class StopResult extends Equatable {
  const StopResult.delivered({this.at})
    : outcome = DeliveryOutcome.delivered,
      reason = null;

  const StopResult.failed(FailureReason this.reason, {this.at})
    : outcome = DeliveryOutcome.failed;

  factory StopResult.fromJson(Map<String, dynamic> json) {
    final at = json['at'] as String?;
    final time = at == null ? null : DateTime.parse(at);
    return switch (DeliveryOutcome.values.byName(json['outcome'] as String)) {
      DeliveryOutcome.delivered => StopResult.delivered(at: time),
      DeliveryOutcome.failed => StopResult.failed(
        FailureReason.values.byName(json['reason'] as String),
        at: time,
      ),
    };
  }

  final DeliveryOutcome outcome;

  /// Only when not delivered.
  final FailureReason? reason;

  /// Clock time of the result; null on results read from older saves.
  final DateTime? at;

  bool get delivered => outcome == DeliveryOutcome.delivered;

  Map<String, dynamic> toJson() => {
    'outcome': outcome.name,
    'reason': ?reason?.name,
    'at': ?at?.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [outcome, reason, at];

  @override
  bool get stringify => true;
}
