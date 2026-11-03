"""Generate src/tokfit/internal/unicode_categories.gleam.

Reads DerivedGeneralCategory.txt from unicode.org and writes a Gleam module
holding a sorted, non-overlapping range table plus a White_Space table.

Run manually when the Unicode revision is bumped. Not part of the build and
not part of CI. The published package contains no script and performs no
network access.

    python3 scripts/gen_unicode_categories.py
"""

import re
import sys
import urllib.request

URL = "https://www.unicode.org/Public/UCD/latest/ucd/extracted/DerivedGeneralCategory.txt"
TARGET = "src/tokfit/internal/unicode_categories.gleam"

# The general categories the o200k_base pattern needs, rolled up to the eight
# classes the matcher distinguishes.
CLASSES = {
    "Lu": "LetterUpper",
    "Lt": "LetterTitle",
    "Lm": "LetterModifier",
    "Lo": "LetterOther",
    "Ll": "LetterLower",
    "Mn": "MarkOther",
    "Mc": "MarkOther",
    "Me": "MarkOther",
    "Nd": "Number",
    "Nl": "Number",
    "No": "Number",
}

CLASS_INDEX = {
    "LetterUpper": 0,
    "LetterTitle": 1,
    "LetterModifier": 2,
    "LetterOther": 3,
    "LetterLower": 4,
    "MarkOther": 5,
    "Number": 6,
    "Other": 7,
}

# Unicode White_Space. Zs is folded in here, not into Other, because the
# pattern needs to tell a space from a symbol.
SPACES = [
    (0x0009, 0x000D), (0x0020, 0x0020), (0x0085, 0x0085), (0x00A0, 0x00A0),
    (0x1680, 0x1680), (0x2000, 0x200A), (0x2028, 0x2029), (0x202F, 0x202F),
    (0x205F, 0x205F), (0x3000, 0x3000),
]

HEADER = '''//// GENERATED FILE. DO NOT EDIT.
//// Source: {url}
//// Unicode revision: {revision}
//// Regenerate with: python3 scripts/gen_unicode_categories.py
////
//// A sorted, non-overlapping range table, interleaved as lo, hi, class index.
//// The hot path is `category_list`, which classifies codepoints in input
//// order. Each lookup scans the table from the head, so its cost grows with
//// the number of ranges before the codepoint; with 2,716 ranges that is small
//// enough to accept.

import gleam/list

/// A Unicode general category, rolled up to the eight classes the
/// o200k_base pre-tokenizer distinguishes.
pub type Category {{
  LetterUpper
  LetterTitle
  LetterModifier
  LetterOther
  LetterLower
  MarkOther
  Number
  Other
}}

/// How many codepoint ranges the table holds.
pub fn range_count() -> Int {{
  {count}
}}

/// The general category of `codepoint`. Total: every value in 0..=0x10FFFF.
///
/// A linear scan. Use `category_list` when classifying many codepoints.
pub fn category(codepoint: Int) -> Category {{
  let #(found, _) = seek(ranges, 0, codepoint)
  to_category(found)
}}

/// The categories of `codepoints`, in the same order and of the same length.
///
/// Codepoints are classified in input order, which is how the pre-tokenizer
/// reads text. Each lookup scans the sorted range table from the head, so its
/// cost grows with the number of ranges before the codepoint; with 2,716
/// ranges that is small enough to accept.
pub fn category_list(codepoints: List(Int)) -> List(Category) {{
  walk(codepoints, ranges, 0, [])
  |> list.reverse()
}}

fn walk(
  codepoints: List(Int),
  table: List(Int),
  index: Int,
  acc: List(Category),
) -> List(Category) {{
  case codepoints {{
    [] -> acc
    [codepoint, ..rest] -> {{
      let #(found, next) = seek(table, index, codepoint)
      case found {{
        -1 -> walk(rest, table, next, [Other, ..acc])
        _ -> walk(rest, table, next, [to_category(found), ..acc])
      }}
    }}
  }}
}}

/// Advance to the first range whose `hi` is at least `target`.
///
/// Returns that range's class index, or -1 when no range covers `target`.
/// The second element is the caller's `index`, returned unchanged.
fn seek(table: List(Int), index: Int, target: Int) -> #(Int, Int) {{
  case table {{
    [lo, hi, class, ..rest] ->
      case target <= hi {{
        True ->
          case target >= lo {{
            True -> #(class, index)
            False -> #(-1, index)
          }}
        False -> seek(rest, index + 3, target)
      }}
    _ -> #(-1, index)
  }}
}}

fn to_category(index: Int) -> Category {{
  case index {{
    0 -> LetterUpper
    1 -> LetterTitle
    2 -> LetterModifier
    3 -> LetterOther
    4 -> LetterLower
    5 -> MarkOther
    6 -> Number
    _ -> Other
  }}
}}

/// True when `codepoint` has the Unicode `White_Space` property.
///
/// Ten ranges, so a linear scan is correct and fast enough.
pub fn is_space(codepoint: Int) -> Bool {{
  in_spaces(spaces, codepoint)
}}

fn in_spaces(table: List(Int), codepoint: Int) -> Bool {{
  case table {{
    [lo, hi, ..rest] ->
      case codepoint > hi {{
        True -> in_spaces(rest, codepoint)
        False -> codepoint >= lo
      }}
    _ -> False
  }}
}}

const ranges = [
{ranges}
]

const spaces = [
{spaces}
]
'''


def revision(text):
    match = re.search(r"^# DerivedGeneralCategory-(\S+)\.txt", text, re.M)
    if not match:
        raise SystemExit("could not read the Unicode revision from the source")
    return match.group(1)


def parse(text):
    kept = []
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line or ";" not in line:
            continue
        codes, _, category = line.partition(";")
        category = category.strip()
        if category not in CLASSES:
            continue
        lo, _, hi = codes.strip().partition("..")
        kept.append((int(lo, 16), int(hi or lo, 16), CLASS_INDEX[CLASSES[category]]))
    kept.sort()
    for (lo, hi, _), (next_lo, _, _) in zip(kept, kept[1:]):
        if next_lo <= hi:
            raise SystemExit(f"overlapping ranges at U+{lo:04X} and U+{next_lo:04X}")
    return kept


def check_disjoint_from_whitespace(kept):
    space_set = set()
    for lo, hi in SPACES:
        space_set.update(range(lo, hi + 1))
    for lo, hi, _ in kept:
        if lo in space_set:
            raise SystemExit(f"U+{lo:04X} is both White_Space and a kept class")
        if any(point in space_set for point in (lo, hi)):
            raise SystemExit(f"U+{lo:04X}..U+{hi:04X} overlaps White_Space")


def wrap(values, indent="  "):
    # One value per line with a trailing comma: that is what `gleam format`
    # does to a list literal this long, so the output is already format-clean
    # when written.
    return "\n".join(f"{indent}{value}," for value in values)


def main():
    print(f"downloading {URL}")
    with urllib.request.urlopen(URL) as response:
        text = response.read().decode("utf-8")
    rev = revision(text)
    kept = parse(text)
    check_disjoint_from_whitespace(kept)
    flat = []
    for lo, hi, class_index in kept:
        flat.extend([f"{lo:#x}", f"{hi:#x}", f"{class_index}"])
    spaces = []
    for lo, hi in SPACES:
        spaces.extend([f"{lo:#x}", f"{hi:#x}"])
    body = HEADER.format(
        url=URL,
        revision=rev,
        count=len(kept),
        ranges=wrap(flat),
        spaces=wrap(spaces),
    )
    with open(TARGET, "w") as handle:
        handle.write(body)
    print(f"wrote {TARGET}: {len(kept)} ranges, {len(SPACES)} space ranges")
    return 0


if __name__ == "__main__":
    sys.exit(main())
