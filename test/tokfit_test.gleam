import gleam/list
import gleam/string
import tokfit
import gleeunit

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

/// A handle holds the vocabulary and nothing that changes, so one handle answers
/// as many calls as the caller has. This is what makes a loop over documents
/// cost one table parse instead of one per document.
pub fn one_tokenizer_answers_every_call_the_same_test() {
  let tokenizer = tokfit.tokenizer()
  let assert 2 = tokfit.count(tokenizer, "hello world")
  let assert 2 = tokfit.count(tokenizer, "hello world")
  let reused = tokfit.count(tokenizer, "hello world")
  let assert 2 = reused
  let assert 2 = tokfit.count(tokenizer, "hello world")
  let assert 2 = tokfit.count(tokfit.tokenizer(), "hello world")
}

pub fn zero_budget_trims_everything_test() {
  let trimmed =
    tokfit.trim_to_budget(tokfit.tokenizer(), "hello world", 0)
  let assert "" = trimmed.text
  let assert 0 = trimmed.tokens
  let assert 0 = trimmed.characters
  let assert 2 = trimmed.dropped_pieces
}

pub fn negative_budget_trims_everything_test() {
  let trimmed =
    tokfit.trim_to_budget(tokfit.tokenizer(), "hello world", -5)
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

pub fn trim_result_is_self_consistent_test() {
  let tokenizer = tokfit.tokenizer()
  let text = "Hello, world! 1234 don't stop now"
  list.each([1, 2, 3, 4, 6, 9, 12], fn(budget) {
    let trimmed = tokfit.trim_to_budget(tokenizer, text, budget)
    let assert True = trimmed.tokens == tokfit.count(tokenizer, trimmed.text)
    let assert True = trimmed.characters == string.length(trimmed.text)
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
  let trimmed =
    tokfit.trim_to_budget(tokfit.tokenizer(), "hello world", 1000)
  let assert "hello world" = trimmed.text
  let assert 2 = trimmed.tokens
  let assert 0 = trimmed.dropped_pieces
}

pub fn trim_only_drops_from_the_end_test() {
  let trimmed =
    tokfit.trim_to_budget(tokfit.tokenizer(), "hello world", 1)
  let assert "hello" = trimmed.text
  let assert 1 = trimmed.tokens
}

pub fn encoding_name_is_o200k_test() {
  let assert "o200k_base" = tokfit.encoding_name()
}

pub fn trim_characters_counts_codepoints_test() {
  let trimmed =
    tokfit.trim_to_budget(tokfit.tokenizer(), "日本語のテキスト", 1000)
  let assert 8 = trimmed.characters
  let assert 8 = string.length(trimmed.text)
}
