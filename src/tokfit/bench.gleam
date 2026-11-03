//// A fixed workload for external timing.
////
////     time gleam run -m tokfit/bench
////
//// Not a test. `gleam_stdlib` 1.0.5 exposes no clock, so the timing is done
//// by the shell. This prints the input size and the token count; the wall
//// clock covers the one-off vocabulary load plus the tokenizing, and no CLI
//// path loads without tokenizing, so the two cannot be split from outside.
////
//// The vocabulary is loaded once and reused, which is the point: the same run
//// with a fresh handle per pass would measure the 199,998-entry parse instead
//// of the tokenizing.

import gleam/int
import gleam/io
import gleam/string
import tokfit

/// How many times the sample block is repeated to fill the input.
const passes = 2000

const samples = [
  "The quick brown fox jumps over the lazy dog.",
  "def count(text: String) -> Int { 1 }",
  "日本語のテキストです",
  "emoji \u{1F600}\u{1F389} and math ∑∫≈",
  "{\"json\": [true, false, null]}",
]

/// Load the vocabulary, build the fixed input, and print its size and count.
pub fn main() -> Nil {
  let tokenizer = tokfit.tokenizer()
  let input = string.repeat(string.join(samples, "\n"), passes)
  let tokens = tokfit.count(tokenizer, input)
  io.println("tokfit benchmark")
  io.println(
    "  input: "
    <> int.to_string(string.byte_size(input))
    <> " bytes, "
    <> int.to_string(string.length(input))
    <> " graphemes, "
    <> int.to_string(passes)
    <> " passes",
  )
  io.println("  tokens: " <> int.to_string(tokens))
  io.println("  timing: time gleam run -m tokfit/bench")
  Nil
}
