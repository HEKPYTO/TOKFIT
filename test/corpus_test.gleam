import corpus
import gleam/list
import tokfit/internal/bpe
import tokfit/internal/o200k_ranks
import tokfit/internal/pretokenize
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn corpus_is_not_empty_test() {
  let assert True = list.length(corpus.cases()) >= 30
}

pub fn corpus_matches_oracle_exactly_test() {
  let ranks = o200k_ranks.ranks()
  let assert [] = mismatches(ranks)
}

/// Every case that disagrees, as `#(text, expected, actual)`, so a failure
/// names the input rather than stopping at the first one.
///
/// `o200k_ranks.ranks()` re-parses all 199,998 entries on every call, so the
/// table is built once here and the per-case count is folded by hand. Thirty
/// `tokfit.count` calls would cost thirty table parses.
fn mismatches(ranks: bpe.Ranks) -> List(#(String, Int, Int)) {
  list.fold(corpus.cases(), [], fn(kept, entry) {
    let corpus.Case(text: text, tokens: expected) = entry
    let actual = count_with(ranks, text)
    case actual == expected {
      True -> kept
      False -> [#(text, expected, actual), ..kept]
    }
  })
}

fn count_with(ranks: bpe.Ranks, text: String) -> Int {
  list.fold(pretokenize.split(text), 0, fn(total, piece) {
    total + bpe.piece_token_count(ranks, piece)
  })
}
