#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

"""Export .lproj/Localizable.strings from the String Catalog.

`swift build` (non-Xcode SPM) does not compile .xcstrings into .strings, so
Bundle.module cannot resolve localized strings from the catalog directly. This
script exports the languages the app actually ships (en source + zh-Hans) into
legacy .lproj/*.strings files that SPM resource processing understands.

Usage: python3 scripts/export_strings.py [lang ...]   (default: en zh-Hans)
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src/MacApp/Resources/Localizable.xcstrings")


def escape(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def value(entry: dict, lang: str):
    loc = entry.get("localizations", {})
    if lang in loc:
        return loc[lang].get("stringUnit", {}).get("value")
    return None


def main() -> None:
    langs = sys.argv[1:] or ["en", "zh-Hans"]
    data = json.load(open(SRC))
    strings = data["strings"]
    src_lang = data.get("sourceLanguage", "en")

    for lang in langs:
        lines = []
        for key in sorted(strings.keys()):
            entry = strings[key]
            v = value(entry, lang)
            if v is None and lang == src_lang:
                v = key  # source language: the key is the value
            if v is None:
                continue
            lines.append(f'"{escape(key)}" = "{escape(v)}";')
        outdir = os.path.join(ROOT, f"src/MacApp/Resources/{lang}.lproj")
        os.makedirs(outdir, exist_ok=True)
        with open(os.path.join(outdir, "Localizable.strings"), "w") as f:
            f.write("\n".join(lines) + "\n")
        print(f"{lang}: {len(lines)} keys")


if __name__ == "__main__":
    main()
