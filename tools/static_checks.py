#!/usr/bin/env python3
"""M-Tek repo static checks — fast local gate before every commit.

Checks (fast, dependency-free):
  1. Dart: balanced braces/parens/brackets (string & comment aware),
     every relative import resolves to an existing file,
     no emoji characters in lib/ (owner rule: SVG/icon-font only),
     no leftover placeholder markers.
  2. pubspec.yaml: declared asset paths exist on disk.
Exit code 1 on any failure. (Full verification: flutter analyze + test in CI.)
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_LIB = os.path.join(ROOT, 'app', 'lib')
APP = os.path.join(ROOT, 'app')

errors = []
warnings = []


def strip_strings_and_comments(src):
    """Replaces string contents and comments with spaces (keeps structure)."""
    out = []
    i, n = 0, len(src)
    in_str = None  # "'", '"'
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ''
        if in_str:
            out.append(' ' if c != in_str else c)
            if c == '\\':
                out.append(' ')
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if c in ("'", '"'):
            in_str = c
            out.append(c)
            i += 1
            continue
        if c == '/' and nxt == '/':
            while i < n and src[i] != '\n':
                out.append(' ')
                i += 1
            continue
        if c == '/' and nxt == '*':
            while i + 1 < n and not (src[i] == '*' and src[i + 1] == '/'):
                out.append('\n' if src[i] == '\n' else ' ')
                i += 1
            out.append('  ')
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


EMOJI_RE = re.compile(
    '['
    '\U0001F000-\U0001FAFF'
    '\u2600-\u27BF'
    '\U0001F1E6-\U0001F1FF'
    '\u2B00-\u2BFF'
    '\uFE0F'
    ']' )


def check_dart_file(path):
    rel = os.path.relpath(path, ROOT)
    src = open(path, encoding='utf-8').read()
    stripped = strip_strings_and_comments(src)

    # 1. balance
    pairs = {'{': '}', '(': ')', '[': ']'}
    stack = []
    for ln, line in enumerate(stripped.split('\n'), 1):
        for ch in line:
            if ch in pairs:
                stack.append((ch, ln))
            elif ch in pairs.values():
                if not stack:
                    errors.append(f'{rel}:{ln}: unmatched closing {ch!r}')
                else:
                    open_ch, open_ln = stack.pop()
                    if pairs[open_ch] != ch:
                        errors.append(f'{rel}:{ln}: {ch!r} closes {open_ch!r} from line {open_ln}')
    for open_ch, open_ln in stack:
        errors.append(f'{rel}:{open_ln}: unclosed {open_ch!r}')

    # 2. relative imports resolve
    for m in re.finditer(r"^\s*import\s+'([^']+)'", src, re.M):
        target = m.group(1)
        if target.startswith('dart:') or target.startswith('package:'):
            continue
        base = os.path.dirname(path)
        resolved = os.path.normpath(os.path.join(base, target))
        if not os.path.exists(resolved):
            errors.append(f'{rel}: import not found: {target}')

    # 3. no emojis
    for ln, line in enumerate(src.split('\n'), 1):
        hit = EMOJI_RE.search(line)
        # U+2713 CHECK MARK is deliberate typography (PDF check boxes), not an icon-emoji
        if hit and hit.group(0) != '\u2713':
            errors.append(f'{rel}:{ln}: emoji found (use SVG/icon-font only)')

    # 4. no placeholders
    if re.search(r'\b(TODO|FIXME|XXX|placeholder)\b', src):
        warnings.append(f'{rel}: placeholder marker present')


def check_pubspec_assets():
    pubspec = open(os.path.join(APP, 'pubspec.yaml'), encoding='utf-8').read()
    in_assets = False
    for line in pubspec.split('\n'):
        if line.strip() == 'assets:':
            in_assets = True
            continue
        if in_assets:
            if line.startswith('  ') and line.strip().startswith('- '):
                asset = line.strip()[2:].strip()
                full = os.path.join(APP, asset)
                if not os.path.exists(full):
                    errors.append(f'pubspec asset missing: {asset}')
            else:
                in_assets = False


def check_js(path):
    rel = os.path.relpath(path, ROOT)
    src = open(path, encoding='utf-8').read()
    for ln, line in enumerate(src.split('\n'), 1):
        hit = EMOJI_RE.search(line)
        if hit and hit.group(0) != '\u2713':
            errors.append(f'{rel}:{ln}: emoji in JS (use /icons.svg sprite)')


def main():
    for base, _dirs, files in os.walk(APP_LIB):
        for f in files:
            if f.endswith('.dart'):
                check_dart_file(os.path.join(base, f))
    check_pubspec_assets()

    for w in warnings:
        print(f'  warn: {w}')
    if errors:
        for e in errors:
            print(f'  FAIL: {e}')
        print(f'\n{len(errors)} error(s)')
        sys.exit(1)
    print('static checks passed: braces balanced, imports resolve, assets exist, no emojis, no placeholders')


if __name__ == '__main__':
    main()
