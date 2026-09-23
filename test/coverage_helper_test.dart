// Loads every file under lib/ so `flutter test --coverage` reports all of
// them (files never imported by a test are absent from coverage/lcov.info).
// Behavior is asserted by the tests next to each file; this one only imports.
// ignore_for_file: unused_import

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/app.dart';
import 'package:routebreeze/core/config/env.dart';
import 'package:routebreeze/core/di/injector.dart';
import 'package:routebreeze/core/error/failure.dart';
import 'package:routebreeze/core/geo/geo_math.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/geo/polyline_codec.dart';
import 'package:routebreeze/core/network/api_client.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';
import 'package:routebreeze/core/session/session_state.dart';
import 'package:routebreeze/core/theme/rb_theme.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/core/widgets/rb_feedback.dart';
import 'package:routebreeze/core/widgets/rb_text_field.dart';
import 'package:routebreeze/features/addresses/data/places_api.dart';
import 'package:routebreeze/features/addresses/domain/address_field.dart';
import 'package:routebreeze/features/addresses/domain/address_form_validator.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/addresses/domain/suggestion.dart';
import 'package:routebreeze/features/addresses/presentation/address_field_widget.dart';
import 'package:routebreeze/features/addresses/presentation/address_form_cubit.dart';
import 'package:routebreeze/features/addresses/presentation/addresses_screen.dart';
import 'package:routebreeze/features/location/data/geolocator_location_service.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/domain/location_service.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';
import 'package:routebreeze/features/lock/data/local_auth_service.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';
import 'package:routebreeze/features/lock/domain/relock_policy.dart';
import 'package:routebreeze/features/lock/presentation/lock_cubit.dart';
import 'package:routebreeze/features/lock/presentation/lock_screen.dart';
import 'package:routebreeze/features/navigation/domain/deviation_detector.dart';
import 'package:routebreeze/features/navigation/domain/recalc_policy.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_cubit.dart';
import 'package:routebreeze/features/navigation/presentation/navigation_screen.dart';
import 'package:routebreeze/features/route/data/route_storage.dart';
import 'package:routebreeze/features/route/data/routes_api.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:routebreeze/features/route/domain/route_planner.dart';
import 'package:routebreeze/features/route/domain/route_repository.dart';
import 'package:routebreeze/features/route/presentation/map_markers.dart';
import 'package:routebreeze/features/route/presentation/route_cubit.dart';
import 'package:routebreeze/features/route/presentation/route_format.dart';
import 'package:routebreeze/features/route/presentation/route_map_objects.dart';
import 'package:routebreeze/features/route/presentation/route_screen.dart';
import 'package:routebreeze/features/route/presentation/route_sheet.dart';
import 'package:routebreeze/main.dart' as app_main;

void main() {
  test('coverage helper', () {});
}
