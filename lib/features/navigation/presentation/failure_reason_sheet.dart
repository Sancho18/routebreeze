import 'package:flutter/material.dart';

import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../route/domain/stop_result.dart';
import '../../route/presentation/stop_result_labels.dart';

/// Bottom sheet that asks why the next stop was not delivered. It closes
/// with the reason picked, or with null when dismissed.
class FailureReasonSheet extends StatelessWidget {
  const FailureReasonSheet({super.key});

  static const String title = 'Por que não foi entregue?';

  static Future<FailureReason?> show(BuildContext context) =>
      showModalBottomSheet<FailureReason>(
        context: context,
        backgroundColor: context.rb.surface200,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RbRadius.lg),
          ),
        ),
        builder: (_) => const FailureReasonSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    return SafeArea(
      top: false,
      // With large text the list can outgrow the sheet; it then scrolls.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(RbSpace.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: RbText.heading.copyWith(color: rb.ink)),
            const SizedBox(height: RbSpace.s2),
            for (final (i, reason) in FailureReason.values.indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: rb.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  reason.label,
                  style: RbText.bodyStrong.copyWith(color: rb.ink),
                ),
                onTap: () => Navigator.of(context).pop(reason),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
