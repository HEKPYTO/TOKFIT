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

/// Every case that disagrees, as `#(text, expected, actual)`, so a failure
/// names the input rather than stopping at the first one.
fn mismatches(tokenizer: tokfit.Tokenizer) -> List(#(String, Int, Int)) {
  list.fold(corpus.cases, [], fn(kept, entry) {
    let corpus.CorpusCase(text: text, tokens: expected) = entry
    let actual = tokfit.count(tokenizer, text)
    case actual == expected {
      True -> kept
      False -> [#(text, expected, actual), ..kept]
    }
  })
}
