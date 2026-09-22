import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/route_plan.dart';

/// Local persistence of the active route (OFFL-03, OFFL-05).
abstract class RouteStorage {
  Future<void> save(RoutePlan plan);

  /// The persisted plan, or null when there is none.
  Future<RoutePlan?> load();

  Future<void> clear();
}

/// `shared_preferences` implementation: one JSON string under [key].
class RouteStorageImpl implements RouteStorage {
  static const String key = 'active_route';

  @override
  Future<void> save(RoutePlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(plan.toJson()));
  }

  /// A corrupt record counts as no route and is removed.
  @override
  Future<RoutePlan?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return RoutePlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await prefs.remove(key);
      return null;
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
