#!/usr/bin/env python3
"""
Emit `--additional-intervals` flags for fontconvert.py covering every
Japanese codepoint actually used in the i18n translations.

Reading the YAML directly (rather than hardcoding ranges) keeps the
font footprint tight: the Ubuntu UI fonts get exactly the kana, kanji
and CJK punctuation that japanese.yaml uses, nothing more. If new
translations introduce new kanji, re-run convert-builtin-fonts.sh.
"""
import os
import sys
import yaml

YAML_PATH = os.path.join(
    os.path.dirname(__file__),
    "..", "..", "I18n", "translations", "japanese.yaml",
)

# Hiragana, Katakana, and CJK Symbols & Punctuation (「」、。 etc.) are
# small enough that we always include the full block — costs ~250 glyphs
# but lets future translation tweaks land without a font rebuild.
ALWAYS_INCLUDE = [
    (0x3000, 0x303F),  # CJK Symbols and Punctuation
    (0x3040, 0x309F),  # Hiragana
    (0x30A0, 0x30FF),  # Katakana
]


def collect_japanese_codepoints(path):
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    cps = set()
    for key, value in data.items():
        if key.startswith("_") or not isinstance(value, str):
            continue
        for ch in value:
            cp = ord(ch)
            # Anything in CJK Unified Ideographs (or extensions). We never
            # need to add Latin-1 / ASCII here — those come from Ubuntu.
            if 0x3400 <= cp <= 0x4DBF or 0x4E00 <= cp <= 0x9FFF:
                cps.add(cp)
    return sorted(cps)


def merge_runs(cps):
    """Group consecutive codepoints into (lo, hi) runs to shrink the CLI."""
    if not cps:
        return []
    runs = [[cps[0], cps[0]]]
    for cp in cps[1:]:
        if cp == runs[-1][1] + 1:
            runs[-1][1] = cp
        else:
            runs.append([cp, cp])
    return [(lo, hi) for lo, hi in runs]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else YAML_PATH
    cjk = collect_japanese_codepoints(path)

    args = []
    for lo, hi in ALWAYS_INCLUDE:
        args.append(f"--additional-intervals=0x{lo:04X},0x{hi:04X}")
    for lo, hi in merge_runs(cjk):
        args.append(f"--additional-intervals=0x{lo:04X},0x{hi:04X}")

    print(" ".join(args))


if __name__ == "__main__":
    main()
