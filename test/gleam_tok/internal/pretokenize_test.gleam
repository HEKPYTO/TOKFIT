import gleam/list
import gleam/string
import gleam_tok/internal/pretokenize

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

pub fn split_is_deterministic_test() {
  let input = "Hello, world! 1234 don't 日本語"
  let assert True = pretokenize.split(input) == pretokenize.split(input)
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
