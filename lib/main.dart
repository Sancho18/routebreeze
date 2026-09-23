import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.ensureConfigured();
  await configureDependencies();
  runApp(const RouteBreezeApp());
}
