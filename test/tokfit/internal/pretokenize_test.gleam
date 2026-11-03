import gleam/list
import gleam/string
import tokfit/internal/pretokenize

pub fn split_roundtrips_test() {
  let inputs = [
    "",
    "hello world",
    "Hello, world!",
    "  leading and trailing   ",
    "\n\nnewlines\r\n\r\n",
    "1234567890",
    "don't can't it'll we've I'm you'll he'd",
    "日本語のテキストです",
    "ภาษาไทย",
    "مرحبا بالعالم",
    "שלום עולם",
    "emoji 😀🎉 and math ∑∫",
    "a1b2c3",
    "https://example.com/path?q=1&r=2",
    "   ",
    "a",
    " ",
    "\n",
    "a\u{0301}e\u{0300}",
    "nbsp\u{00A0}here",
  ]
  list.each(inputs, fn(input) {
    let assert True = input == string.join(pretokenize.split(input), "")
  })
}

pub fn split_never_produces_empty_pieces_test() {
  list.each(pretokenize.split("Hello,  world!\n\n1234"), fn(piece) {
    let assert False = piece == ""
  })
}

pub fn split_splits_latin_words_test() {
  let assert ["hello", " world"] = pretokenize.split("hello world")
}

pub fn split_keeps_english_contractions_attached_test() {
  // The contraction group is inside branch 1, so it is part of the same
  // pre-token. `don't` is one `o200k_base` token, which it could not be if the
  // pre-tokenizer split it in two.
  let assert ["don't"] = pretokenize.split("don't")
  let assert ["we've"] = pretokenize.split("we've")
  let assert ["I'll"] = pretokenize.split("I'll")
  let assert ["I'm"] = pretokenize.split("I'm")
  let assert ["can't"] = pretokenize.split("can't")
  let assert ["he'd"] = pretokenize.split("he'd")
  // Uppercase runs match branch 2, but the contraction still applies.
  let assert ["DON'T"] = pretokenize.split("DON'T")
  let assert ["YOU'LL"] = pretokenize.split("YOU'LL")
}

pub fn split_folds_long_s_into_a_contraction_suffix_test() {
  // U+017F LATIN SMALL LETTER LONG S simple-case-folds to `s`, so `(?i:'s)`
  // matches it and the whole group stays in the word.
  let assert ["a'ſ"] = pretokenize.split("a'ſ")
  let assert ["A'ſ"] = pretokenize.split("A'ſ")
  let assert ["a'ſ", "x"] = pretokenize.split("a'ſx")
}

pub fn split_does_not_take_a_bare_apostrophe_into_the_word_test() {
  // The contraction group is optional, so an apostrophe with no suffix is not
  // part of the word: it starts the next piece under branch 4.
  let assert ["a", "'x"] = pretokenize.split("a'x")
  let assert ["a", "'"] = pretokenize.split("a'")
}

pub fn split_lets_a_leading_combining_mark_join_the_upperish_run_test() {
  // The mark is not the optional punctuation; it matches branch 2's upperish
  // run instead, so it stays with the letter that follows.
  let assert ["\u{0301}", "\"a"] = pretokenize.split("\u{0301}\"a")
}

pub fn split_backtracks_the_upperish_run_to_reach_a_lowering_char_test() {
  // Branch 1 is ordered, not longest-match: `upperish*` gives back the
  // trailing Lu/Lt run so `lowering+` can match the last lowering char.
  let assert ["日本語", "ABC"] = pretokenize.split("日本語ABC")
  let assert ["Aア", "B"] = pretokenize.split("AアB")
  let assert ["\u{0301}", "A"] = pretokenize.split("\u{0301}A")
  let assert ["日本語", "AB"] = pretokenize.split("日本語AB")
  let assert ["日本語Ab", "C"] = pretokenize.split("日本語AbC")
  // Nothing to give back when `lowering+` already matches, and branch 1 cannot
  // match at all when all of the run is Lu/Lt.
  let assert ["日本語hello"] = pretokenize.split("日本語hello")
  let assert ["ABC日本語"] = pretokenize.split("ABC日本語")
}

pub fn split_groups_digits_in_threes_test() {
  let assert ["123", "456", "789", "0"] = pretokenize.split("1234567890")
}

pub fn split_keeps_a_newline_run_together_test() {
  let assert ["a", "\n\n", "b"] = pretokenize.split("a\n\nb")
}

pub fn split_treats_cjk_as_one_letter_run_test() {
  let assert ["日本語のテキストです"] = pretokenize.split("日本語のテキストです")
}

pub fn split_stops_a_space_run_at_the_last_newline_test() {
  // Branch 5 ends at the last newline of the run, so the two trailing spaces
  // are a separate piece.
  let assert ["a", "\n\n", " ", " b"] = pretokenize.split("a\n\n  b")
}

pub fn split_uses_the_trailing_space_branch_before_end_test() {
  // Branch 6 matches a run minus its last character when more follows.
  let assert ["a", "  ", " b"] = pretokenize.split("a   b")
}

pub fn split_takes_a_whole_space_run_at_end_of_input_test() {
  let assert ["a", "   "] = pretokenize.split("a   ")
}

pub fn split_treats_a_single_space_before_a_word_as_part_of_the_word_test() {
  let assert ["a", " b"] = pretokenize.split("a b")
}

pub fn split_keeps_a_space_run_before_punctuation_separate_test() {
  // Branch 4 needs a symbol after its optional literal space.
  let assert ["a", " ", " !!!"] = pretokenize.split("a  !!!")
}

pub fn split_works_in_codepoint_space_test() {
  let hi = string.to_utf_codepoints("hi")
  let assert True = [hi] == pretokenize.split_codepoints(hi)
  let assert [] = pretokenize.split_codepoints([])
}

pub fn splits_text_longer_than_the_javascript_stack_test() {
  // 360,000 codepoints. Building the classified list with a non-tail-recursive
  // helper overflowed Node's stack at a third of this, and the Erlang target
  // never noticed. Every list here is accumulated in reverse so the recursion
  // depth stays flat no matter how long the input is.
  let long = string.repeat("hello world ", 30_000)
  let pieces = pretokenize.split(long)
  let assert True = pieces != []
  let assert True = long == string.join(pieces, "")
}
