import fixtures/corpus
import gleam/list
import gleeunit
import tokfit

pub fn main() {
  gleeunit.main()
}

pub fn corpus_is_not_empty_test() {
  let assert True = list.length(corpus.cases) >= 30
}

pub fn corpus_matches_oracle_exactly_test() {
  let tokenizer = tokfit.tokenizer()
  let assert [] = mismatches(tokenizer)
}

/// One input whose count or ids disagree with the oracle, naming the expected
/// value before the actual one.
pub type Mismatch {
  Mismatch(text: String, count: #(Int, Int), ids: #(List(Int), List(Int)))
}

/// Every case that disagrees, so a failure shows all of them and both the
/// count and the ids rather than stopping at the first.
fn mismatches(tokenizer: tokfit.Tokenizer) -> List(Mismatch) {
  list.fold(corpus.cases, [], fn(kept, entry) {
    let corpus.CorpusCase(text: text, tokens: expected_count, ids: expected_ids) =
      entry
    let actual_count = tokfit.count(tokenizer, text)
    let actual_ids = tokfit.encode(tokenizer, text)
    case actual_count == expected_count && actual_ids == expected_ids {
      True -> kept
      False -> [
        Mismatch(text: text, count: #(expected_count, actual_count), ids: #(
          expected_ids,
          actual_ids,
        )),
        ..kept
      ]
    }
  })
}
