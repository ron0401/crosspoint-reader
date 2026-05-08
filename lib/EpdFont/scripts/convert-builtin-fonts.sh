#!/bin/bash

set -e

cd "$(dirname "$0")"

READER_FONT_STYLES=("Regular" "Italic" "Bold" "BoldItalic")
NOTOSERIF_FONT_SIZES=(12 14 16 18)
NOTOSANS_FONT_SIZES=(12 14 16 18)
OPENDYSLEXIC_FONT_SIZES=(8 10 12 14)

for size in ${NOTOSERIF_FONT_SIZES[@]}; do
  for style in ${READER_FONT_STYLES[@]}; do
    font_name="notoserif_${size}_$(echo $style | tr '[:upper:]' '[:lower:]')"
    font_path="../builtinFonts/source/NotoSerif/NotoSerif-${style}.ttf"
    output_path="../builtinFonts/${font_name}.h"
    python fontconvert.py $font_name $size $font_path --2bit --compress --pnum > $output_path
    echo "Generated $output_path"
  done
done

for size in ${NOTOSANS_FONT_SIZES[@]}; do
  for style in ${READER_FONT_STYLES[@]}; do
    font_name="notosans_${size}_$(echo $style | tr '[:upper:]' '[:lower:]')"
    font_path="../builtinFonts/source/NotoSans/NotoSans-${style}.ttf"
    output_path="../builtinFonts/${font_name}.h"
    python fontconvert.py $font_name $size $font_path --2bit --compress --pnum > $output_path
    echo "Generated $output_path"
  done
done

for size in ${OPENDYSLEXIC_FONT_SIZES[@]}; do
  for style in ${READER_FONT_STYLES[@]}; do
    font_name="opendyslexic_${size}_$(echo $style | tr '[:upper:]' '[:lower:]')"
    font_path="../builtinFonts/source/OpenDyslexic/OpenDyslexic-${style}.otf"
    output_path="../builtinFonts/${font_name}.h"
    python fontconvert.py $font_name $size $font_path --2bit --compress > $output_path
    echo "Generated $output_path"
  done
done

UI_FONT_SIZES=(10 12)
UI_FONT_STYLES=("Regular" "Bold")

# Japanese coverage for the UI fonts: Ubuntu provides Latin glyphs, Noto Sans JP
# is added as a fontstack fallback for any codepoint Ubuntu doesn't have. The
# helper script derives the exact set of CJK codepoints from japanese.yaml so
# the UI font only carries glyphs that are actually used.
JP_INTERVALS=$(python japanese_intervals.py)
# Use the JP-only subsetted fonts so the fallback covers ONLY kana/kanji/CJK
# punctuation. Without subsetting, NotoSansJP would also backfill every Latin
# codepoint Ubuntu lacks, doubling the resulting font size and blowing the
# 6.5 MB app partition. Generate the subsets with `pyftsubset` (see
# japanese_intervals.py for the codepoint set).
JP_FONT_REGULAR="../builtinFonts/source/NotoSansJP/NotoSansJP-Regular-jp-only.ttf"
JP_FONT_BOLD="../builtinFonts/source/NotoSansJP/NotoSansJP-Bold-jp-only.ttf"

for size in ${UI_FONT_SIZES[@]}; do
  for style in ${UI_FONT_STYLES[@]}; do
    font_name="ubuntu_${size}_$(echo $style | tr '[:upper:]' '[:lower:]')"
    font_path="../builtinFonts/source/Ubuntu/Ubuntu-${style}.ttf"
    output_path="../builtinFonts/${font_name}.h"
    if [ "$style" = "Bold" ]; then
      jp_path="$JP_FONT_BOLD"
    else
      jp_path="$JP_FONT_REGULAR"
    fi
    if [ -f "$jp_path" ]; then
      # --no-kerning is required: adding ~460 CJK glyphs pushes the kerning
      # class count past 255 (which the on-device uint8_t can't represent).
      # Kerning is barely visible at 10/12 pt UI sizes anyway.
      python fontconvert.py $font_name $size $font_path $jp_path --no-kerning $JP_INTERVALS > $output_path
    else
      echo "WARNING: $jp_path not found, building $font_name without Japanese coverage" >&2
      python fontconvert.py $font_name $size $font_path > $output_path
    fi
    echo "Generated $output_path"
  done
done

# notosans_8_regular is the SMALL_FONT_ID used for button hints, status bars,
# and keyboard tips — it must include JP coverage too, otherwise those areas
# render mojibake when language=JA.
if [ -f "$JP_FONT_REGULAR" ]; then
  python fontconvert.py notosans_8_regular 8 \
    ../builtinFonts/source/NotoSans/NotoSans-Regular.ttf \
    "$JP_FONT_REGULAR" \
    --no-kerning $JP_INTERVALS \
    > ../builtinFonts/notosans_8_regular.h
else
  python fontconvert.py notosans_8_regular 8 ../builtinFonts/source/NotoSans/NotoSans-Regular.ttf > ../builtinFonts/notosans_8_regular.h
fi

echo ""
echo "Running compression verification..."
python verify_compression.py ../builtinFonts/
