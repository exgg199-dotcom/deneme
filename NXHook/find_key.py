#!/usr/bin/env python3
"""Print localization keys whose value mentions the verification error.

Handles binary/XML plist .strings and old-style ASCII/UTF-16 .strings.
Usage: find_key.py <path-to-.strings>
"""
import sys
import plistlib
import re

TOKENS = ('Doğrula', 'oğrula', 'Verif', 'verif', 'doğrulan', 'Valid', 'geçersiz')


def emit(path, k, v):
    print(f"{path} :: KEY={k!r} VAL={str(v)!r}")


def try_plist(path):
    try:
        with open(path, 'rb') as fh:
            d = plistlib.load(fh)
    except Exception:
        return False
    if not isinstance(d, dict):
        return False
    hit = False
    for k, v in d.items():
        sv = str(v)
        if any(t in sv for t in TOKENS):
            emit(path, k, v)
            hit = True
    return True if hit else None  # None = parsed but no hit


def try_text(path):
    for enc in ('utf-16', 'utf-8', 'latin-1'):
        try:
            with open(path, 'r', encoding=enc) as fh:
                text = fh.read()
        except Exception:
            continue
        # old-style:  "key" = "value";
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
                             text):
            k, v = m.group(1), m.group(2)
            if any(t in v for t in TOKENS):
                emit(path, k, v)
        return


def main():
    path = sys.argv[1]
    res = try_plist(path)
    if res is None or res is False:
        # not a hitting plist (or not a plist) -> try text form
        try_text(path)


if __name__ == '__main__':
    main()
