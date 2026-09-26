//// Throughput measurement.
////
////     time gleam run -m tokfit/bench
////
//// Not a test. `gleam_stdlib` 1.0.5 exposes no clock, so the timing is done
//// by the shell. This prints the two numbers worth diffing: the input size and
//// the token count. Divide the first by the wall clock to get bytes per
//// second.
////
//// The merge table is built once and reused. `tokfit.count` rebuilds it on
//// every call, so calling it per pass would measure the 199,998-entry table
//// parse instead of the tokenizing, which is the number worth having.

import gleam/int
import gleam/io
import gleam/list
import gleam/string
import tokfit/internal/bpe
import tokfit/internal/o200k_ranks
import tokfit/internal/pretokenize

/// How many times the sample block is repeated to fill the input.
const passes = 2000

const samples = [
  "The quick brown fox jumps over the lazy dog.",
  "def count(text: String) -> Int { 1 }",
  "日本語のテキストです",
  "emoji \u{1F600}\u{1F389} and math ∑∫≈",
  "{\"json\": [true, false, null]}",
]

pub fn main() -> Nil {
  let input = string.repeat(string.join(samples, "\n"), passes)
  let tokens = count(input, o200k_ranks.ranks())
  io.println("tokfit benchmark")
  io.println(
    "  input: "
    <> int.to_string(string.byte_size(input))
    <> " bytes, "
    <> int.to_string(string.length(input))
    <> " codepoints, "
    <> int.to_string(passes)
    <> " passes",
  )
  io.println("  tokens: " <> int.to_string(tokens))
  io.println("  timing: time gleam run -m tokfit/bench")
  Nil
}

fn count(text: String, ranks: bpe.Ranks) -> Int {
  list.fold(pretokenize.split(text), 0, fn(total, piece) {
    total + bpe.piece_token_count(ranks, piece)
  })
}
