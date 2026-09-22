import 'package:equatable/equatable.dart';

/// One Places Autocomplete prediction (ADDR-02).
class Suggestion extends Equatable {
  const Suggestion(this.placeId, this.mainText, this.secondaryText);

  final String placeId;
  final String mainText;
  final String secondaryText;

  @override
  List<Object?> get props => [placeId, mainText, secondaryText];

  @override
  bool get stringify => true;
}
