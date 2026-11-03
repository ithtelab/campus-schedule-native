"""Extend the existing OFL font subset without dropping any already bundled characters.

Usage: python scripts/add-campus-heading-glyphs.py path/to/MaShanZheng-Regular.ttf
Official source: https://github.com/google/fonts/tree/main/ofl/mashanzheng
Requires fontTools; the app and normal build do not depend on Python or this script.
"""
from pathlib import Path
import sys
from fontTools import subset
from fontTools.ttLib import TTFont

target = Path(__file__).resolve().parents[1] / "CampusSchedule/Resources/Fonts/CampusHand.ttf"
with TTFont(target) as previous:
    required = set(previous.getBestCmap()) | {ord(c) for c in "课堂入场券"}
    previous_name = previous["name"].getDebugName(6)
with TTFont(sys.argv[1]) as source:
    if source["name"].getDebugName(6) != previous_name:
        raise ValueError("Use the same original typeface as the bundled subset")
    if not required.issubset(source.getBestCmap()):
        raise ValueError("Original font is missing required heading characters")
    options = subset.Options()
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    options.name_languages = [0x409]
    worker = subset.Subsetter(options=options)
    worker.populate(unicodes=required)
    worker.subset(source)
    source.save(target)
with TTFont(target) as result:
    assert required.issubset(result.getBestCmap())
print(f"Preserved existing characters; bundled font now covers {len(required)} characters")
