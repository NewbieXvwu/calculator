#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
"""把 UWP 的 .resw 本地化资源批量转换为 Xcode String Catalog (.xcstrings)。

用法：
    python3 Tools/resw_to_xcstrings.py Resources      # -> src/MacApp/Resources/Localizable.xcstrings
    python3 Tools/resw_to_xcstrings.py CEngineStrings # -> src/MacApp/Resources/CEngineStrings.xcstrings

源目录固定为 src/Calculator/Resources/<locale>/<name>.resw，
源语言 en-US。UWP 与 Xcode 的语言代码差异做了映射（zh-CN → zh-Hans 等）。
"""

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RESW_ROOT = REPO_ROOT / "src" / "Calculator" / "Resources"
OUT_DIR = REPO_ROOT / "src" / "MacApp" / "Resources"

SOURCE_LOCALE = "en-US"

# UWP locale → Xcode/BCP-47 locale。
# 未列出的按「仅保留语言子标签」处理（af-ZA → af）。
LOCALE_MAP = {
    "en-US": "en",
    "en-GB": "en-GB",
    "es-ES": "es",
    "es-MX": "es-MX",
    "fr-FR": "fr",
    "fr-CA": "fr-CA",
    "pt-PT": "pt-PT",
    "pt-BR": "pt-BR",
    "zh-CN": "zh-Hans",
    "zh-TW": "zh-Hant",
    "sr-Latn-RS": "sr-Latn",
    "az-Latn-AZ": "az",
}


def map_locale(uwp: str) -> str:
    if uwp in LOCALE_MAP:
        return LOCALE_MAP[uwp]
    return uwp.split("-")[0]


def parse_resw(path: Path) -> dict:
    """返回 {key: value}。忽略 .resw 头部模板与注释。"""
    strings = {}
    root = ET.parse(path).getroot()
    for data in root.iter("data"):
        name = data.get("name")
        value = data.findtext("value")
        if name is None or value is None:
            continue
        strings[name] = value
    return strings


def main() -> int:
    basename = sys.argv[1] if len(sys.argv) > 1 else "Resources"
    out_name = "Localizable" if basename == "Resources" else basename

    locales = sorted(
        p.name for p in RESW_ROOT.iterdir() if (p / f"{basename}.resw").is_file()
    )
    if SOURCE_LOCALE not in locales:
        print(f"error: source locale {SOURCE_LOCALE} not found", file=sys.stderr)
        return 1

    source_strings = parse_resw(RESW_ROOT / SOURCE_LOCALE / f"{basename}.resw")
    print(f"{basename}: {len(source_strings)} keys, {len(locales)} locales")

    catalog_strings = {
        key: {"localizations": {}} for key in source_strings
    }

    seen_targets = {}
    for locale in locales:
        target = map_locale(locale)
        if target in seen_targets:
            print(
                f"warn: {locale} and {seen_targets[target]} both map to {target}; "
                f"keeping {seen_targets[target]}",
                file=sys.stderr,
            )
            continue
        seen_targets[target] = locale

        for key, value in parse_resw(RESW_ROOT / locale / f"{basename}.resw").items():
            entry = catalog_strings.get(key)
            if entry is None:
                continue  # 该 key 不在源语言中，跳过
            entry["localizations"][target] = {
                "stringUnit": {"state": "translated", "value": value}
            }

    catalog = {
        "sourceLanguage": "en",
        "strings": catalog_strings,
        "version": "1.0",
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / f"{out_name}.xcstrings"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"wrote {out_path} ({out_path.stat().st_size / 1024 / 1024:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
