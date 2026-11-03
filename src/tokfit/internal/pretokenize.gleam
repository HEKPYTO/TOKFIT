//// The `o200k_base` pre-tokenizer.
////
//// OpenAI's pattern is a flat alternation of seven branches, so it is written
//// out here as explicit matchers over Unicode general categories. There is no
//// pure-Gleam regex engine on Hex, and the `cl100k_base` variant uses
//// possessive quantifiers that neither ECMAScript nor PCRE provides, so a
//// pattern hand-off would be encoding-specific in two places instead of one.
////
//// Four places where the obvious reading is wrong, all pinned by the tests:
////
//// - Branch 1 is ordered, not longest-match: when `lowering+` is empty it
////   gives back the trailing `Lu`/`Lt` run so a lowering char can satisfy it.
//// - Branch 4's optional character is a literal space, not `\s`.
//// - Branch 5's greedy `\s*` backtracks, so the match ends at the last
////   newline of the whitespace run, not at the end of the run.
//// - Branch 6's `(?!\S)` means the run must be followed by another space or by
////   end of input, so it takes the whole run at the end and the run minus its
////   last character otherwise.

import gleam/int
import gleam/list
import gleam/string
import tokfit/internal/unicode_categories as u

/// One codepoint, its general category, and its numeric value.
///
/// The numeric value is carried alongside the `UtfCodepoint` because
/// `gleam_stdlib` offers no way to build a `UtfCodepoint` from an `Int`, so a
/// pre-token can never be turned back into a `String` once it holds plain
/// integers. It is also what the newline, slash, space, and apostrophe tests
/// compare against.
type Char {
  Char(utf: UtfCodepoint, codepoint: Int, category: u.Category)
}

/// Any category the pattern treats as a letter, that is `\p{L}`.
pub fn is_letter(category: u.Category) -> Bool {
  case category {
    u.LetterUpper -> True
    u.LetterTitle -> True
    u.LetterModifier -> True
    u.LetterOther -> True
    u.LetterLower -> True
    u.MarkOther -> False
    u.Number -> False
    u.Other -> False
  }
}

/// `[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]`
pub fn is_upperish(category: u.Category) -> Bool {
  case category {
    u.LetterUpper -> True
    u.LetterTitle -> True
    u.LetterModifier -> True
    u.LetterOther -> True
    u.MarkOther -> True
    u.LetterLower -> False
    u.Number -> False
    u.Other -> False
  }
}

/// `[\p{Ll}\p{Lm}\p{Lo}\p{M}]`
pub fn is_lowering(category: u.Category) -> Bool {
  case category {
    u.LetterLower -> True
    u.LetterOther -> True
    u.LetterModifier -> True
    u.MarkOther -> True
    u.LetterUpper -> False
    u.LetterTitle -> False
    u.Number -> False
    u.Other -> False
  }
}

/// `\p{Lu}` or `\p{Lt}`: upperish but not lowering.
fn is_upper_only(category: u.Category) -> Bool {
  is_upperish(category) && !is_lowering(category)
}

fn is_number_char(char: Char) -> Bool {
  char.category == u.Number
}

fn is_upperish_char(char: Char) -> Bool {
  is_upperish(char.category)
}

fn is_lowering_char(char: Char) -> Bool {
  is_lowering(char.category)
}

fn is_newline_char(char: Char) -> Bool {
  char.codepoint == 0x0D || char.codepoint == 0x0A
}

fn is_slash_or_newline_char(char: Char) -> Bool {
  is_newline_char(char) || char.codepoint == 0x2F
}

fn is_space_char(char: Char) -> Bool {
  u.is_space(char.codepoint)
}

/// `[^\s\p{L}\p{N}]`. Note `\p{M}` is **not** excluded, so a combining mark
/// counts as a symbol here.
fn is_symbol_char(char: Char) -> Bool {
  !is_space_char(char) && !is_letter(char.category) && !is_number_char(char)
}

/// `[^\r\n\p{L}\p{N}]`, minus the upperish class. A mark may be the optional
/// character, but the regex backtracks so the mark matches the upperish run
/// instead, which makes leaving marks to the run alone equivalent. Note this
/// **does** include whitespace other than a newline, which is why `" world"` is
/// a single pre-token.
fn is_leading_punct_char(char: Char) -> Bool {
  !is_newline_char(char)
  && !is_letter(char.category)
  && !is_number_char(char)
  && !is_upperish(char.category)
}

/// Take characters while `predicate` holds. Returns what was taken and what is
/// left, both in order.
///
/// Accumulated in reverse and reversed once, because the loop is tail
/// recursive and a `String` can be far longer than the JavaScript stack.
fn take_while(
  chars: List(Char),
  predicate: fn(Char) -> Bool,
) -> #(List(Char), List(Char)) {
  take_until(chars, predicate, [])
}

fn take_until(
  chars: List(Char),
  predicate: fn(Char) -> Bool,
  acc: List(Char),
) -> #(List(Char), List(Char)) {
  case chars {
    [char, ..rest] ->
      case predicate(char) {
        True -> take_until(rest, predicate, [char, ..acc])
        False -> #(list.reverse(acc), chars)
      }
    [] -> #(list.reverse(acc), [])
  }
}

/// The optional `[^\r\n\p{L}\p{N}]?` shared by branches 1 and 2.
fn take_optional_leading_punct(chars: List(Char)) -> #(List(Char), List(Char)) {
  case chars {
    [char, ..rest] ->
      case is_leading_punct_char(char) {
        True -> #([char], rest)
        False -> #([], chars)
      }
    [] -> #([], [])
  }
}

fn lower_ascii(codepoint: Int) -> Int {
  case codepoint >= 0x41 && codepoint <= 0x5A {
    True -> codepoint + 0x20
    False ->
      case codepoint {
        // U+017F LATIN SMALL LETTER LONG S simple-case-folds to `s`, so the
        // case-insensitive contraction group accepts it as a suffix.
        0x17F -> 0x73
        _ -> codepoint
      }
  }
}

/// How many characters `(?i:'s|'t|'re|'ve|'m|'ll|'d)?` takes at the front of
/// `chars`: 0, 1, 2, or 3 counting the apostrophe.
///
/// The apostrophe is inside the group, so `"'ll"` is three characters, not two.
/// Skipping it is the difference between one pre-token for `"don't"` and two,
/// and the real vocabulary settles that: `don't` is a single `o200k_base`
/// token, and a BPE token can never span a pre-token boundary. The group is
/// optional, so a bare apostrophe is not consumed at all.
fn contraction_length(chars: List(Char)) -> Int {
  case chars {
    [quote, ..rest] ->
      case quote.codepoint == 0x27 {
        True -> {
          let suffix = suffix_length(rest)
          case suffix {
            0 -> 0
            _ -> 1 + suffix
          }
        }
        False -> 0
      }
    [] -> 0
  }
}

/// How many characters follow the apostrophe: 0, 1, or 2.
fn suffix_length(chars: List(Char)) -> Int {
  case chars {
    [first, second, ..] ->
      case lower_ascii(first.codepoint), lower_ascii(second.codepoint) {
        0x72, 0x65 -> 2
        0x76, 0x65 -> 2
        0x6C, 0x6C -> 2
        _, _ -> one_suffix_length(first.codepoint)
      }
    [first, ..] -> one_suffix_length(first.codepoint)
    [] -> 0
  }
}

fn one_suffix_length(codepoint: Int) -> Int {
  case lower_ascii(codepoint) {
    0x73 -> 1
    0x74 -> 1
    0x6D -> 1
    0x64 -> 1
    _ -> 0
  }
}

fn with_contraction(body: List(Char), rest: List(Char)) -> #(List(Char), Int) {
  let extra = list.take(rest, contraction_length(rest))
  let taken = list.append(body, extra)
  #(taken, list.length(taken))
}

/// Branches 1 and 2 as one matcher.
///
/// Branch 1 is `upperish* lowering+ contraction?` and branch 2 is
/// `upperish+ lowering* contraction?`, tried in that order. The greedy
/// `upperish*` takes the whole upperish run. If the character after it is not
/// lowering, `lowering+` is empty and the engine gives characters back from the
/// end of the run until one is lowering-capable, which is exactly the trailing
/// `Lu`/`Lt` run. The match is then the run without that tail, and no
/// contraction follows because the next character is a letter. When the whole
/// run is `Lu`/`Lt`, branch 1 cannot match at all and branch 2 takes it.
fn branch_letter_run(chars: List(Char)) -> #(List(Char), Int) {
  let #(optional, rest) = take_optional_leading_punct(chars)
  let #(upper, after_upper) = take_while(rest, is_upperish_char)
  let #(lower, after_lower) = take_while(after_upper, is_lowering_char)
  case lower {
    [] -> {
      let run = list.length(upper)
      let tail = upper_only_tail_length(upper)
      case tail == 0 || tail == run {
        True ->
          case upper {
            // Both branches need at least one letter, so the optional
            // punctuation is given back rather than emitted as a piece of its
            // own.
            [] -> #([], 0)
            _ -> with_contraction(list.append(optional, upper), after_upper)
          }
        False -> {
          let taken = list.append(optional, list.take(upper, run - tail))
          #(taken, list.length(taken))
        }
      }
    }
    _ ->
      with_contraction(
        list.append(optional, list.append(upper, lower)),
        after_lower,
      )
  }
}

/// The length of the trailing run of `Lu`/`Lt` characters.
fn upper_only_tail_length(chars: List(Char)) -> Int {
  upper_only_tail_length_from(chars, 0)
}

fn upper_only_tail_length_from(chars: List(Char), run: Int) -> Int {
  case chars {
    [char, ..rest] ->
      case is_upper_only(char.category) {
        True -> upper_only_tail_length_from(rest, run + 1)
        False -> upper_only_tail_length_from(rest, 0)
      }
    [] -> run
  }
}

/// Branch 3, `\p{N}{1,3}`.
fn branch_digits(chars: List(Char)) -> #(List(Char), Int) {
  let #(digits, _) = take_while(chars, is_number_char)
  let length = int.min(list.length(digits), 3)
  #(list.take(digits, length), length)
}

/// Branch 4, ` ?[^\s\p{L}\p{N}]+[\r\n/]*`. The optional character is a
/// literal space, not `\s`.
fn branch_symbols(chars: List(Char)) -> #(List(Char), Int) {
  let #(space, rest) = take_literal_space(chars)
  let #(symbols, after_symbols) = take_while(rest, is_symbol_char)
  case symbols {
    [] -> #([], 0)
    _ -> {
      let #(trailing, _) = take_while(after_symbols, is_slash_or_newline_char)
      let taken = list.append(space, list.append(symbols, trailing))
      #(taken, list.length(taken))
    }
  }
}

fn take_literal_space(chars: List(Char)) -> #(List(Char), List(Char)) {
  case chars {
    [char, ..rest] ->
      case char.codepoint == 0x20 {
        True -> #([char], rest)
        False -> #([], chars)
      }
    [] -> #([], [])
  }
}

/// Branch 5, `\s*[\r\n]+`. The greedy `\s*` backtracks, so the match ends at
/// the last newline of the whitespace run.
fn branch_newline_run(chars: List(Char)) -> #(List(Char), Int) {
  let #(space, _) = take_while(chars, is_space_char)
  let kept = through_last_newline(space)
  #(kept, list.length(kept))
}

fn through_last_newline(chars: List(Char)) -> List(Char) {
  case last_newline_index(chars) {
    -1 -> []
    index -> list.take(chars, index + 1)
  }
}

fn last_newline_index(chars: List(Char)) -> Int {
  last_newline_index_from(chars, -1, 0)
}

fn last_newline_index_from(chars: List(Char), found: Int, seen: Int) -> Int {
  case chars {
    [] -> found
    [char, ..rest] ->
      case is_newline_char(char) {
        True -> last_newline_index_from(rest, seen, seen + 1)
        False -> last_newline_index_from(rest, found, seen + 1)
      }
  }
}

/// Branch 6, `\s+(?!\S)`. At the end of input the whole run matches; otherwise
/// the run must be followed by another space, so it matches all but its last
/// character, and a run of one matches nothing at all.
fn branch_trailing_space(chars: List(Char)) -> #(List(Char), Int) {
  let #(space, after) = take_while(chars, is_space_char)
  let run = list.length(space)
  case after {
    [] -> #(space, run)
    _ ->
      case run >= 2 {
        True -> #(list.take(space, run - 1), run - 1)
        False -> #([], 0)
      }
  }
}

/// Branch 7, `\s+`.
fn branch_space_run(chars: List(Char)) -> #(List(Char), Int) {
  let #(space, _) = take_while(chars, is_space_char)
  #(space, list.length(space))
}

/// Try every branch in the pattern's order and take the first that matches.
fn match_branch(chars: List(Char)) -> List(Char) {
  let #(_, letter_count) = branch_letter_run(chars)
  let #(_, digit_count) = branch_digits(chars)
  let #(_, symbol_count) = branch_symbols(chars)
  let #(_, newline_count) = branch_newline_run(chars)
  let #(_, trailing_count) = branch_trailing_space(chars)
  let #(_, space_count) = branch_space_run(chars)
  let length =
    first_match([
      letter_count,
      digit_count,
      symbol_count,
      newline_count,
      trailing_count,
      space_count,
    ])
  list.take(chars, length)
}

fn first_match(counts: List(Int)) -> Int {
  case counts {
    [0, ..rest] -> first_match(rest)
    [length, ..] -> length
    [] -> 0
  }
}

/// The pre-tokens of `text`, in order, concatenating back to `text`.
pub fn split(text: String) -> List(String) {
  text
  |> string.to_utf_codepoints()
  |> split_codepoints()
  |> list.map(string.from_utf_codepoints)
}

/// The pre-tokens of `codepoints`, in codepoint space.
///
/// Categories are resolved once, in one forward pass, and then carried
/// alongside the codepoints so every branch is a single scan. The argument is
/// `List(UtfCodepoint)` rather than `List(Int)` because `gleam_stdlib` cannot
/// turn an `Int` back into a `UtfCodepoint`, so a pre-token of integers could
/// never be turned back into a `String`.
pub fn split_codepoints(
  codepoints: List(UtfCodepoint),
) -> List(List(UtfCodepoint)) {
  go(classify(codepoints), [])
}

fn classify(codepoints: List(UtfCodepoint)) -> List(Char) {
  let numbers = list.map(codepoints, string.utf_codepoint_to_int)
  zip(codepoints, numbers, u.category_list(numbers))
}

/// Three parallel lists into one, shortest-wins.
///
/// Tail recursive with an accumulator, for the same reason as `take_while`:
/// this runs once per codepoint of the input.
fn zip(
  codepoints: List(UtfCodepoint),
  numbers: List(Int),
  categories: List(u.Category),
) -> List(Char) {
  zip_into(codepoints, numbers, categories, []) |> list.reverse
}

fn zip_into(
  codepoints: List(UtfCodepoint),
  numbers: List(Int),
  categories: List(u.Category),
  acc: List(Char),
) -> List(Char) {
  case codepoints, numbers, categories {
    [utf, ..rest_codepoints],
      [codepoint, ..rest_numbers],
      [category, ..rest_categories]
    ->
      zip_into(rest_codepoints, rest_numbers, rest_categories, [
        Char(utf: utf, codepoint: codepoint, category: category),
        ..acc
      ])
    _, _, _ -> acc
  }
}

fn go(
  remaining: List(Char),
  acc: List(List(UtfCodepoint)),
) -> List(List(UtfCodepoint)) {
  case remaining {
    [] -> list.reverse(acc)
    _ -> {
      let matched = match_branch(remaining)
      case matched {
        // Every codepoint is covered by some branch, so this only keeps a
        // hypothetical gap from looping forever.
        [] -> go(list.drop(remaining, 1), acc)
        _ ->
          go(list.drop(remaining, list.length(matched)), [
            codepoints_of(matched),
            ..acc
          ])
      }
    }
  }
}

fn codepoints_of(chars: List(Char)) -> List(UtfCodepoint) {
  list.map(chars, fn(char) { char.utf })
}
