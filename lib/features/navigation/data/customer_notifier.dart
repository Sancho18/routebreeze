import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a message for the customer to another app, where the driver picks
/// the contact.
abstract class CustomerNotifier {
  /// Opens the share sheet with [text], anchored to [origin] where the
  /// platform needs one (iPad). False when the sheet could not open.
  Future<bool> notify(String text, {Rect? origin});
}

/// [CustomerNotifier] over the system share sheet (`share_plus`): no
/// permission and no contact stored in the app.
class SharePlusCustomerNotifier implements CustomerNotifier {
  @override
  Future<bool> notify(String text, {Rect? origin}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
