import gleam/list
import gleam_tok/internal/unicode_categories as u

pub fn range_count_is_populated_test() {
  let assert True = u.range_count() > 1000
}

pub fn ascii_letters_are_letters_test() {
  let assert u.LetterLower = u.category(0x61)
  let assert u.LetterUpper = u.category(0x41)
  let assert u.LetterOther = u.category(0x00AA)
}

pub fn ascii_digits_are_numbers_test() {
  let assert u.Number = u.category(0x30)
  let assert u.Number = u.category(0x39)
}

pub fn cjk_is_letter_other_test() {
  let assert u.LetterOther = u.category(0x4E00)
  let assert u.LetterOther = u.category(0x3042)
}

pub fn arabic_and_hebrew_are_letter_other_test() {
  let assert u.LetterOther = u.category(0x0627)
  let assert u.LetterOther = u.category(0x05D0)
}

pub fn devanagari_is_letter_other_test() {
  let assert u.LetterOther = u.category(0x0905)
}

pub fn combining_mark_is_mark_test() {
  let assert u.MarkOther = u.category(0x0300)
}

pub fn punctuation_is_other_test() {
  let assert u.Other = u.category(0x2C)
  let assert u.Other = u.category(0x21)
}

pub fn unassigned_codepoint_is_other_test() {
  let assert u.Other = u.category(0x0378)
}

pub fn whitespace_detection_test() {
  let assert True = u.is_space(0x20)
  let assert True = u.is_space(0x09)
  let assert True = u.is_space(0x0A)
  let assert False = u.is_space(0x41)
  let assert True = u.is_space(0x00A0)
  let assert True = u.is_space(0x3000)
}

pub fn category_list_matches_single_lookups_test() {
  let input = [0x41, 0x61, 0x30, 0x2C, 0x4E00, 0x0300, 0x0905, 0x0627]
  let expected = [
    u.LetterUpper,
    u.LetterLower,
    u.Number,
    u.Other,
    u.LetterOther,
    u.MarkOther,
    u.LetterOther,
    u.LetterOther,
  ]
  let assert True = expected == u.category_list(input)
}

pub fn category_list_preserves_length_and_order_test() {
  let input = codepoints(0x20, 0x7E)
  let assert True = list.length(input) == list.length(u.category_list(input))
  let assert Ok(u.Other) = list.first(u.category_list([0x2C, 0x41]))
  let assert Ok(u.LetterUpper) = list.last(u.category_list([0x2C, 0x41]))
}

/// `from` to `to` inclusive. `gleam/list` has no `range/2`.
fn codepoints(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..codepoints(from + 1, to)]
  }
}
