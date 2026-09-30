import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../../addresses/domain/stop.dart';
import '../data/navigation_app_launcher.dart';
import '../domain/navigation_app.dart';

/// Bottom sheet that hands [stop] over to another navigation app. It closes
/// once an app takes the stop; a failure keeps it open with the reason, so
/// the other app can be tried.
class OpenInAppSheet extends StatefulWidget {
  const OpenInAppSheet({super.key, required this.stop, required this.launcher});

  final Stop stop;
  final NavigationAppLauncher launcher;

  static const String title = 'Abrir em outro app';
  static const String caption =
      'O acompanhamento continua quando você voltar ao RouteBreeze.';

  static String failure(NavigationApp app) =>
      'Não foi possível abrir o ${app.label}.';

  static Future<void> show(
    BuildContext context, {
    required Stop stop,
    required NavigationAppLauncher launcher,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.rb.surface200,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(RbRadius.lg)),
    ),
    builder: (_) => OpenInAppSheet(stop: stop, launcher: launcher),
  );

  @override
  State<OpenInAppSheet> createState() => _OpenInAppSheetState();
}

class _OpenInAppSheetState extends State<OpenInAppSheet> {
  bool _opening = false;
  NavigationApp? _failed;

  Future<void> _open(NavigationApp app) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = null;
    });
    final opened = await widget.launcher.open(app, widget.stop);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _opening = false;
        _failed = app;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    final failed = _failed;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(RbSpace.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              OpenInAppSheet.title,
              style: RbText.heading.copyWith(color: rb.ink),
            ),
            const SizedBox(height: RbSpace.s1),
            Text(
              OpenInAppSheet.caption,
              style: RbText.caption.copyWith(color: rb.inkMuted),
            ),
            const SizedBox(height: RbSpace.s2),
            for (final (i, app) in NavigationApp.values.indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: rb.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  app.label,
                  style: RbText.bodyStrong.copyWith(color: rb.ink),
                ),
                trailing: Icon(Icons.chevron_right, color: rb.inkMuted),
                onTap: () => _open(app),
              ),
            ],
            if (failed != null) ...[
              const SizedBox(height: RbSpace.s2),
              RbInlineError(text: OpenInAppSheet.failure(failed)),
            ],
          ],
        ),
      ),
    );
  }
}
