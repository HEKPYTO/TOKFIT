//// Throughput measurement.
////
////     time gleam run -m gleam_tok/bench
////
//// Not a test. `gleam_stdlib` 1.0.5 exposes no clock, so the timing is done
//// by the shell. This prints the two numbers worth diffing: the input size and
//// the token count. Divide the first by the wall clock to get bytes per
//// second.
////
//// The vocabulary is loaded once and reused, which is the point: the same run
//// with a fresh handle per pass would measure the 199,998-entry parse instead
//// of the tokenizing.

import gleam/int
import gleam/io
import gleam/string
import gleam_tok

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
  let tokenizer = gleam_tok.tokenizer()
  let input = string.repeat(string.join(samples, "\n"), passes)
  let tokens = gleam_tok.count(tokenizer, input)
  io.println("gleam_tok benchmark")
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
  io.println("  timing: time gleam run -m gleam_tok/bench")
  Nil
}
