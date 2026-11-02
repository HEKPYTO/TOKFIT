import gleam/list
import gleam/string
import gleeunit
import tokfit

pub fn main() {
  gleeunit.main()
}

pub fn count_empty_is_zero_test() {
  let assert 0 = tokfit.count(tokfit.tokenizer(), "")
}

pub fn count_matches_length_of_encode_test() {
  let tokenizer = tokfit.tokenizer()
  let inputs = ["", "hello world", "Hello, world!", "1234567890", "don't stop"]
  list.each(inputs, fn(input) {
    let assert True =
      tokfit.count(tokenizer, input)
      == list.length(tokfit.encode(tokenizer, input))
  })
}

pub fn count_known_ascii_test() {
  let tokenizer = tokfit.tokenizer()
  let assert 2 = tokfit.count(tokenizer, "hello world")
  let assert 4 = tokfit.count(tokenizer, "Hello, world!")
}

pub fn encode_ids_are_non_negative_test() {
  let ids = tokfit.encode(tokfit.tokenizer(), "Hello, world! 1234")
  list.each(ids, fn(id) {
    let assert True = id >= 0
  })
}

pub fn zero_budget_trims_everything_test() {
  let trimmed = tokfit.trim_to_budget(tokfit.tokenizer(), "hello world", 0)
  let assert "" = trimmed.text
  let assert 0 = trimmed.tokens
  let assert 0 = trimmed.characters
  let assert 2 = trimmed.dropped_pieces
}

pub fn negative_budget_trims_everything_test() {
  let trimmed = tokfit.trim_to_budget(tokfit.tokenizer(), "hello world", -5)
  let assert "" = trimmed.text
  let assert 0 = trimmed.tokens
}

pub fn trim_never_exceeds_budget_test() {
  let tokenizer = tokfit.tokenizer()
  let text = "Hello, world! 1234 don't stop now"
  list.each([0, 1, 2, 3, 5, 8, 13, 21, 40], fn(budget) {
    let assert True =
      tokfit.trim_to_budget(tokenizer, text, budget).tokens <= budget
  })
}

pub fn trim_returns_a_prefix_test() {
  let tokenizer = tokfit.tokenizer()
  let text = "internationalization hi"
  // The first pre-token costs more than one token, so the whole trim is empty.
  // Skipping it and keeping the cheaper trailing piece would not be a prefix.
  let assert "" = tokfit.trim_to_budget(tokenizer, text, 1).text
  let assert "internationalization" =
    tokfit.trim_to_budget(tokenizer, text, 2).text
  list.each([0, 1, 2, 3, 4, 5, 6], fn(budget) {
    let trimmed = tokfit.trim_to_budget(tokenizer, text, budget)
    let assert True = string.starts_with(text, trimmed.text)
    let assert True = trimmed.tokens == tokfit.count(tokenizer, trimmed.text)
  })
}

pub fn special_token_literals_tokenize_as_ordinary_text_test() {
  let tokenizer = tokfit.tokenizer()
  list.each(["<|endoftext|>", "<|endofprompt|>"], fn(text) {
    let ids = tokfit.encode(tokenizer, text)
    let assert True = ids != []
    // The two special ids are 199999 and 200018, outside the merge table.
    let assert True = list.all(ids, fn(id) { id < 199_998 })
    let assert True = tokfit.count(tokenizer, text) == list.length(ids)
  })
}

pub fn trim_is_monotone_test() {
  let text = "Hello, world! 1234 don't stop now"
  let assert True = monotonic(tokfit.tokenizer(), text, 0, -1, 20)
}

fn monotonic(
  tokenizer: tokfit.Tokenizer,
  text: String,
  budget: Int,
  previous: Int,
  up_to: Int,
) -> Bool {
  case budget > up_to {
    True ->
      monotonic(
        tokenizer,
        text,
        budget + 1,
        tokfit.trim_to_budget(tokenizer, text, budget).tokens,
        up_to,
      )
    False -> tokfit.trim_to_budget(tokenizer, text, up_to).tokens >= previous
  }
}

pub fn trim_over_budget_keeps_everything_test() {
  let trimmed = tokfit.trim_to_budget(tokfit.tokenizer(), "hello world", 1000)
  let assert "hello world" = trimmed.text
  let assert 2 = trimmed.tokens
  let assert 0 = trimmed.dropped_pieces
}

pub fn trim_only_drops_from_the_end_test() {
  let trimmed = tokfit.trim_to_budget(tokfit.tokenizer(), "hello world", 1)
  let assert "hello" = trimmed.text
  let assert 1 = trimmed.tokens
}

pub fn encoding_name_is_o200k_test() {
  let assert "o200k_base" = tokfit.encoding_name()
}

pub fn trim_characters_counts_graphemes_test() {
  let tokenizer = tokfit.tokenizer()
  let trimmed = tokfit.trim_to_budget(tokenizer, "日本語のテキスト", 1000)
  let assert 8 = trimmed.characters
  let assert 8 = string.length(trimmed.text)
  // `e` plus a combining acute accent is one grapheme and two codepoints.
  let combined = tokfit.trim_to_budget(tokenizer, "e\u{301}a", 1000)
  let assert 2 = combined.characters
}
