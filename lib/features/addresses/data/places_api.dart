import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/geo/geo_point.dart';
import '../../../core/network/api_client.dart';
import '../domain/stop.dart';
import '../domain/suggestion.dart';

/// Places API (New) autocomplete and place details; both throw a `Failure` on
/// transport or HTTP errors.
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

  /// Suggestions are biased to a 50 km circle around the start position.
  static const double biasRadiusMeters = 50000;

  static const int maxSuggestions = 5;

  /// Essentials SKU fields; also closes the autocomplete session.
  static const String detailsFieldMask = 'id,formattedAddress,location';

  /// A 200 answer whose body does not have the expected shape.
  static const Failure invalidResponse = ApiFailure(
    null,
    'Resposta inválida da Places API',
  );

  @override
  Future<List<Suggestion>> autocomplete({
    required String input,
    required String sessionToken,
    required GeoPoint bias,
  }) async {
    final response = await _send(
      () => _dio.post<Object?>(
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
    final data = response.data;
    final suggestions = data is Map ? data['suggestions'] : null;
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
      () => _dio.get<Object?>(
        '$baseUrl/places/$placeId',
        queryParameters: {
          'sessionToken': sessionToken,
          'languageCode': 'pt-BR',
          'regionCode': 'br',
        },
        options: Options(headers: {'X-Goog-FieldMask': detailsFieldMask}),
      ),
    );
    final place = response.data;
    if (place is! Map) throw invalidResponse;
    final id = place['id'];
    final address = place['formattedAddress'];
    final location = place['location'];
    if (id is! String || address is! String || location is! Map) {
      throw invalidResponse;
    }
    final lat = location['latitude'];
    final lng = location['longitude'];
    if (lat is! num || lng is! num) throw invalidResponse;
    return Stop(id, address, GeoPoint(lat.toDouble(), lng.toDouble()));
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
