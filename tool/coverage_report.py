#!/usr/bin/env python3
"""Line-coverage report per folder from an lcov trace (stdlib only).

Usage:
    flutter test --coverage
    python3 tool/coverage_report.py [coverage/lcov.info]

Groups `lib/` files into `lib/core`, each `lib/features/<name>` and the
`lib/` root, prints a Markdown table, the files below the threshold and two
totals: every file, and every file except the native-only ones (code that
only runs on a device, see NATIVE_ONLY).
"""

import os
import sys
from collections import OrderedDict

THRESHOLD = 90.0

# Files whose lines need native components (platform entrypoint, plugin
# views) and therefore never execute under `flutter test`.
NATIVE_ONLY = ['lib/main.dart']


def parse_lcov(path):
    """Return {file: (lines_found, lines_hit)} from an lcov trace."""
    files = OrderedDict()
    current = None
    found = hit = 0
    da_found = da_hit = 0
    with open(path, encoding='utf-8') as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith('SF:'):
                current = line[3:].replace('\\', '/')
                found = hit = da_found = da_hit = 0
            elif line.startswith('DA:'):
                _, count = line[3:].split(',', 1)
                da_found += 1
                if int(count.split(',')[0]) > 0:
                    da_hit += 1
            elif line.startswith('LF:'):
                found = int(line[3:])
            elif line.startswith('LH:'):
                hit = int(line[3:])
            elif line == 'end_of_record' and current is not None:
                if found == 0 and da_found:
                    found, hit = da_found, da_hit
                files[current] = (found, hit)
                current = None
    return files


def folder_of(path):
    parts = path.split('/')
    if len(parts) >= 2 and parts[0] == 'lib':
        if parts[1] == 'features' and len(parts) >= 3:
            return 'lib/features/' + parts[2]
        if len(parts) > 2:
            return 'lib/' + parts[1]
        return 'lib (root)'
    return parts[0]


def pct(found, hit):
    return 100.0 if found == 0 else 100.0 * hit / found


def fmt_row(name, found, hit):
    return '| %s | %d | %d | %.1f%% |' % (name, found, hit, pct(found, hit))


def main(argv):
    path = argv[1] if len(argv) > 1 else os.path.join('coverage', 'lcov.info')
    if not os.path.isfile(path):
        sys.stderr.write('lcov trace not found: %s (run flutter test --coverage)\n' % path)
        return 2
    files = parse_lcov(path)
    lib_files = OrderedDict((f, v) for f, v in files.items() if f.startswith('lib/'))
    native = [f for f in NATIVE_ONLY if f in lib_files]

    folders = OrderedDict()
    for name, (found, hit) in lib_files.items():
        key = folder_of(name)
        f_found, f_hit = folders.get(key, (0, 0))
        folders[key] = (f_found + found, f_hit + hit)

    print('## Cobertura de linhas por pasta')
    print()
    print('| Pasta | Linhas | Cobertas | % |')
    print('| --- | ---: | ---: | ---: |')
    for key in sorted(folders, key=lambda k: (k != 'lib/core', k)):
        found, hit = folders[key]
        print(fmt_row(key, found, hit))
    total_found = sum(v[0] for v in lib_files.values())
    total_hit = sum(v[1] for v in lib_files.values())
    excl_found = total_found - sum(lib_files[f][0] for f in native)
    excl_hit = total_hit - sum(lib_files[f][1] for f in native)
    print(fmt_row('**Total (todos os arquivos)**', total_found, total_hit))
    print(fmt_row('**Total (sem native-only)**', excl_found, excl_hit))
    print()
    print('Native-only (excluídos do segundo total): %s' % (', '.join(native) or 'nenhum'))

    below = [(pct(v[0], v[1]), f, v) for f, v in lib_files.items() if pct(v[0], v[1]) < THRESHOLD]
    print()
    if below:
        print('## Arquivos abaixo de %.0f%%' % THRESHOLD)
        print()
        for p, name, (found, hit) in sorted(below):
            print('- %s: %d/%d (%.1f%%)' % (name, hit, found, p))
    else:
        print('Nenhum arquivo abaixo de %.0f%%.' % THRESHOLD)

    low_folders = [k for k, v in folders.items() if pct(v[0], v[1]) < THRESHOLD]
    ok = not low_folders and pct(excl_found, excl_hit) >= THRESHOLD
    print()
    print('Meta ≥ %.0f%% por pasta e no total (sem native-only): %s' % (THRESHOLD, 'OK' if ok else 'NÃO'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
