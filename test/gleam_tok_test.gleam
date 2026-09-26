import gleam/list
import gleam/string
import gleam_tok
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn count_empty_is_zero_test() {
  let assert 0 = gleam_tok.count(gleam_tok.tokenizer(), "")
}

pub fn count_matches_length_of_encode_test() {
  let tokenizer = gleam_tok.tokenizer()
  let inputs = ["", "hello world", "Hello, world!", "1234567890", "don't stop"]
  list.each(inputs, fn(input) {
    let assert True =
      gleam_tok.count(tokenizer, input)
      == list.length(gleam_tok.encode(tokenizer, input))
  })
}

pub fn count_known_ascii_test() {
  let tokenizer = gleam_tok.tokenizer()
  let assert 2 = gleam_tok.count(tokenizer, "hello world")
  let assert 4 = gleam_tok.count(tokenizer, "Hello, world!")
}

pub fn encode_ids_are_non_negative_test() {
  let ids = gleam_tok.encode(gleam_tok.tokenizer(), "Hello, world! 1234")
  list.each(ids, fn(id) {
    let assert True = id >= 0
  })
}

/// A handle holds the vocabulary and nothing that changes, so one handle answers
/// as many calls as the caller has. This is what makes a loop over documents
/// cost one table parse instead of one per document.
pub fn one_tokenizer_answers_every_call_the_same_test() {
  let tokenizer = gleam_tok.tokenizer()
  let assert 2 = gleam_tok.count(tokenizer, "hello world")
  let assert 2 = gleam_tok.count(tokenizer, "hello world")
  let reused = gleam_tok.count(tokenizer, "hello world")
  let assert 2 = reused
  let assert 2 = gleam_tok.count(tokenizer, "hello world")
  let assert 2 = gleam_tok.count(gleam_tok.tokenizer(), "hello world")
}

pub fn zero_budget_trims_everything_test() {
  let trimmed =
    gleam_tok.trim_to_budget(gleam_tok.tokenizer(), "hello world", 0)
  let assert "" = trimmed.text
  let assert 0 = trimmed.tokens
  let assert 0 = trimmed.characters
  let assert 2 = trimmed.dropped_pieces
}

pub fn negative_budget_trims_everything_test() {
  let trimmed =
    gleam_tok.trim_to_budget(gleam_tok.tokenizer(), "hello world", -5)
  let assert "" = trimmed.text
  let assert 0 = trimmed.tokens
}

pub fn trim_never_exceeds_budget_test() {
  let tokenizer = gleam_tok.tokenizer()
  let text = "Hello, world! 1234 don't stop now"
  list.each([0, 1, 2, 3, 5, 8, 13, 21, 40], fn(budget) {
    let assert True =
      gleam_tok.trim_to_budget(tokenizer, text, budget).tokens <= budget
  })
}

pub fn trim_result_is_self_consistent_test() {
  let tokenizer = gleam_tok.tokenizer()
  let text = "Hello, world! 1234 don't stop now"
  list.each([1, 2, 3, 4, 6, 9, 12], fn(budget) {
    let trimmed = gleam_tok.trim_to_budget(tokenizer, text, budget)
    let assert True = trimmed.tokens == gleam_tok.count(tokenizer, trimmed.text)
    let assert True = trimmed.characters == string.length(trimmed.text)
  })
}

pub fn trim_is_monotone_test() {
  let text = "Hello, world! 1234 don't stop now"
  let assert True = monotonic(gleam_tok.tokenizer(), text, 0, -1, 20)
}

fn monotonic(
  tokenizer: gleam_tok.Tokenizer,
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
        gleam_tok.trim_to_budget(tokenizer, text, budget).tokens,
        up_to,
      )
    False -> gleam_tok.trim_to_budget(tokenizer, text, up_to).tokens >= previous
  }
}

pub fn trim_over_budget_keeps_everything_test() {
  let trimmed =
    gleam_tok.trim_to_budget(gleam_tok.tokenizer(), "hello world", 1000)
  let assert "hello world" = trimmed.text
  let assert 2 = trimmed.tokens
  let assert 0 = trimmed.dropped_pieces
}

pub fn trim_only_drops_from_the_end_test() {
  let trimmed =
    gleam_tok.trim_to_budget(gleam_tok.tokenizer(), "hello world", 1)
  let assert "hello" = trimmed.text
  let assert 1 = trimmed.tokens
}

pub fn encoding_name_is_o200k_test() {
  let assert "o200k_base" = gleam_tok.encoding_name()
}

pub fn trim_characters_counts_codepoints_test() {
  let trimmed =
    gleam_tok.trim_to_budget(gleam_tok.tokenizer(), "日本語のテキスト", 1000)
  let assert 8 = trimmed.characters
  let assert 8 = string.length(trimmed.text)
}
