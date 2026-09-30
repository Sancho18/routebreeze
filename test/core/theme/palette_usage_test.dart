import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `RbColors.*` anywhere, or a `Colors.*` constant other than white and
/// transparent.
final _fixedColor = RegExp(r'\b(RbColors\.\w+|Colors\.(\w+))');
const _allowed = {'white', 'transparent'};

/// Fixed color references in the Dart files under [dir], outside
/// `lib/core/theme/`, as `path:line: reference`.
List<String> fixedColorsIn(String dir) => [
  for (final file in Directory(dir).listSync(recursive: true).whereType<File>())
    if (file.path.endsWith('.dart') &&
        !file.path.replaceAll(r'\', '/').startsWith('lib/core/theme/'))
      for (final (i, line) in file.readAsLinesSync().indexed)
        for (final match in _fixedColor.allMatches(line))
          if (match.group(2) == null || !_allowed.contains(match.group(2)))
            '${file.path}:${i + 1}: ${match.group(1)}',
];

void main() {
  test('outside lib/core/theme/ no file references RbColors or a Colors '
      'constant other than white and transparent', () {
    expect(fixedColorsIn('lib'), isEmpty);
  });
}
