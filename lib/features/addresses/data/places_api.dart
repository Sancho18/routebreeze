import 'package:dio/dio.dart';

import '../../../core/geo/geo_point.dart';
import '../../../core/network/api_client.dart';
import '../domain/stop.dart';
import '../domain/suggestion.dart';

/// Places API (New): autocomplete and place details (ADDR-02, ADDR-03).
///
/// Both methods throw a `Failure` on transport or HTTP errors (ADDR-11).
abstract class PlacesApi {
  Future<List<Suggestion>> autocomplete({
    required String input,
    required String sessionToken,
    required GeoPoint bias,
  });

  Future<Stop> details({required String placeId, required String sessionToken});
}

class PlacesApiImpl implements PlacesApi {
  PlacesApiImpl(this._dio);

  final Dio _dio;

  static const String baseUrl = 'https://places.googleapis.com/v1';

  /// Location bias around the start position (spec: 50 km).
  static const double biasRadiusMeters = 50000;

  static const int maxSuggestions = 5;

  /// Essentials SKU fields; also closes the autocomplete session.
  static const String detailsFieldMask = 'id,formattedAddress,location';

  @override
  Future<List<Suggestion>> autocomplete({
    required String input,
    required String sessionToken,
    required GeoPoint bias,
  }) async {
    final response = await _send(
      () => _dio.post<Map<String, dynamic>>(
        '$baseUrl/places:autocomplete',
        data: {
          'input': input,
          'sessionToken': sessionToken,
          'locationBias': {
            'circle': {
              'center': {'latitude': bias.lat, 'longitude': bias.lng},
              'radius': biasRadiusMeters,
            },
          },
          'includedRegionCodes': ['br'],
          'languageCode': 'pt-BR',
        },
      ),
    );
    final suggestions = response.data?['suggestions'];
    if (suggestions is! List) return const [];
    return suggestions
        .map(_toSuggestion)
        .nonNulls
        .take(maxSuggestions)
        .toList();
  }

  @override
  Future<Stop> details({
    required String placeId,
    required String sessionToken,
  }) async {
    final response = await _send(
      () => _dio.get<Map<String, dynamic>>(
        '$baseUrl/places/$placeId',
        queryParameters: {
          'sessionToken': sessionToken,
          'languageCode': 'pt-BR',
          'regionCode': 'br',
        },
        options: Options(headers: {'X-Goog-FieldMask': detailsFieldMask}),
      ),
    );
    final place = response.data!;
    final location = place['location'] as Map<String, dynamic>;
    return Stop(
      place['id'] as String,
      place['formattedAddress'] as String,
      GeoPoint(
        (location['latitude'] as num).toDouble(),
        (location['longitude'] as num).toDouble(),
      ),
    );
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// `placePrediction` entries only; `queryPrediction` entries are skipped.
  /// Without `structuredFormat` the full `text` becomes the main text.
  static Suggestion? _toSuggestion(Object? item) {
    if (item is! Map) return null;
    final prediction = item['placePrediction'];
    if (prediction is! Map) return null;
    final placeId = prediction['placeId'];
    if (placeId is! String) return null;
    final text = _text(prediction['text']);
    final format = prediction['structuredFormat'];
    if (format is! Map) return Suggestion(placeId, text, '');
    return Suggestion(
      placeId,
      _text(format['mainText']),
      _text(format['secondaryText']),
    );
  }

  static String _text(Object? node) =>
      node is Map && node['text'] is String ? node['text'] as String : '';
}
