import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/network/api_client.dart';
import 'package:routebreeze/features/addresses/data/places_api.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/addresses/domain/suggestion.dart';

/// Transport stub: answers every call with [body]/[status] and records the
/// request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.body, [this.status = 200]);

  final String body;
  final int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String prediction(String id, String main, String secondary) =>
    '{"placePrediction":{"placeId":"$id","text":{"text":"$main, $secondary"},'
    '"structuredFormat":{"mainText":{"text":"$main"},'
    '"secondaryText":{"text":"$secondary"}}}}';

void main() {
  const bias = GeoPoint(-23.5614, -46.6559);
  late FakeAdapter adapter;

  PlacesApi api(String body, [int status = 200]) {
    adapter = FakeAdapter(body, status);
    return PlacesApiImpl(buildGoogleDio(apiKey: 'test-key', adapter: adapter));
  }

  group('autocomplete', () {
    test('POSTs the session token, 50 km bias, region BR and pt-BR, and '
        'parses the suggestions', () async {
      final places = api(
        '{"suggestions":['
        '${prediction("p1", "Avenida Paulista, 1000", "São Paulo - SP")},'
        '${prediction("p2", "Avenida Paulista, 1500", "São Paulo - SP")}'
        ']}',
      );

      final result = await places.autocomplete(
        input: 'Av. Paulista',
        sessionToken: 'tok-1',
        bias: bias,
      );

      expect(result, const [
        Suggestion('p1', 'Avenida Paulista, 1000', 'São Paulo - SP'),
        Suggestion('p2', 'Avenida Paulista, 1500', 'São Paulo - SP'),
      ]);
      final sent = adapter.requests.single;
      expect(sent.method, 'POST');
      expect(
        sent.uri.toString(),
        'https://places.googleapis.com/v1/places:autocomplete',
      );
      expect(sent.headers['X-Goog-Api-Key'], 'test-key');
      expect(sent.headers[Headers.contentTypeHeader], 'application/json');
      expect(sent.data, {
        'input': 'Av. Paulista',
        'sessionToken': 'tok-1',
        'locationBias': {
          'circle': {
            'center': {'latitude': -23.5614, 'longitude': -46.6559},
            'radius': 50000.0,
          },
        },
        'includedRegionCodes': ['br'],
        'languageCode': 'pt-BR',
      });
    });

    test('returns at most 5 suggestions', () async {
      final places = api(
        '{"suggestions":[${List.generate(7, (i) => prediction('p$i', 'Rua $i', 'SP')).join(',')}]}',
      );

      final result = await places.autocomplete(
        input: 'Rua',
        sessionToken: 't',
        bias: bias,
      );

      expect(result, hasLength(5));
      expect(result.map((s) => s.placeId), ['p0', 'p1', 'p2', 'p3', 'p4']);
    });

    test('falls back to the full text without structuredFormat and skips '
        'query predictions', () async {
      final places = api(
        '{"suggestions":['
        '{"queryPrediction":{"text":{"text":"pizza perto de mim"}}},'
        '{"placePrediction":{"placeId":"p9","text":{"text":"Praça da Sé"}}}'
        ']}',
      );

      final result = await places.autocomplete(
        input: 'Praça',
        sessionToken: 't',
        bias: bias,
      );

      expect(result, const [Suggestion('p9', 'Praça da Sé', '')]);
    });

    test('empty response body → no suggestions', () async {
      final places = api('{}');

      final result = await places.autocomplete(
        input: 'xyz',
        sessionToken: 't',
        bias: bias,
      );

      expect(result, isEmpty);
    });

    test('HTTP error → ApiFailure with the API message', () async {
      final places = api(
        '{"error":{"code":400,"message":"Invalid input"}}',
        400,
      );

      await expectLater(
        places.autocomplete(input: 'x', sessionToken: 't', bias: bias),
        throwsA(const ApiFailure(400, 'Invalid input')),
      );
    });
  });

  group('details', () {
    test('GETs the place with the session token, pt-BR/BR and the field '
        'mask id,formattedAddress,location, and parses the Stop', () async {
      final places = api(
        '{"id":"p1","formattedAddress":"Av. Paulista, 1000 - Bela Vista, '
        'São Paulo - SP, 01310-100, Brasil",'
        '"location":{"latitude":-23.5651,"longitude":-46.6507}}',
      );

      final stop = await places.details(placeId: 'p1', sessionToken: 'tok-1');

      expect(
        stop,
        const Stop(
          'p1',
          'Av. Paulista, 1000 - Bela Vista, São Paulo - SP, 01310-100, Brasil',
          GeoPoint(-23.5651, -46.6507),
        ),
      );
      final sent = adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.uri.origin, 'https://places.googleapis.com');
      expect(sent.uri.path, '/v1/places/p1');
      expect(sent.uri.queryParameters, {
        'sessionToken': 'tok-1',
        'languageCode': 'pt-BR',
        'regionCode': 'br',
      });
      expect(sent.headers['X-Goog-FieldMask'], 'id,formattedAddress,location');
      expect(sent.headers['X-Goog-Api-Key'], 'test-key');
    });

    test('HTTP error → ApiFailure', () async {
      final places = api(
        '{"error":{"code":404,"message":"Place not found"}}',
        404,
      );

      await expectLater(
        places.details(placeId: 'nope', sessionToken: 't'),
        throwsA(const ApiFailure(404, 'Place not found')),
      );
    });
  });

  test('Stop round-trips through JSON', () {
    const stop = Stop('p1', 'Rua A, 1', GeoPoint(-23.5, -46.6));

    expect(Stop.fromJson(stop.toJson()), stop);
    expect(stop.toJson(), {
      'placeId': 'p1',
      'address': 'Rua A, 1',
      'point': {'lat': -23.5, 'lng': -46.6},
    });
  });
}
