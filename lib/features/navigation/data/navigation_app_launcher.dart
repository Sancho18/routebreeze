import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../addresses/domain/stop.dart';
import '../domain/navigation_app.dart';

/// Hands a stop over to another navigation app.
abstract class NavigationAppLauncher {
  /// False when no app or browser took the link.
  Future<bool> open(NavigationApp app, Stop stop);
}

/// [NavigationAppLauncher] over `url_launcher`: the link opens as an
/// external application, so the installed app answers it.
class UrlNavigationAppLauncher implements NavigationAppLauncher {
  @override
  Future<bool> open(NavigationApp app, Stop stop) async {
    try {
      return await launchUrl(
        app.linkTo(stop),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      return false;
    }
  }
}
