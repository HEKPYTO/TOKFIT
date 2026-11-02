//// Byte-level BPE token counting and budget trimming for OpenAI's
//// `o200k_base` encoding.
////
//// Pure Gleam on both the Erlang and JavaScript runtimes. No NIFs, no FFI,
//// no network access, and no filesystem access at run time.

import gleam/list
import gleam/string
import tokfit/internal/bpe
import tokfit/internal/o200k_ranks
import tokfit/internal/pretokenize

/// A loaded `o200k_base` vocabulary.
///
/// Build one with `tokenizer/0` and keep it. Every call on a fresh handle
/// reparses 199,998 entries, which costs seconds, so a loop that builds a
/// handle per call spends all its time in the parser.
///
/// Gleam has no module-level mutable state and this package takes no
/// target-specific dependency, so a plain function cannot cache the table
/// across calls. Holding the handle is the only way to pay for it once.
pub opaque type Tokenizer {
  Tokenizer(ranks: bpe.Ranks)
}

/// A prefix that fits inside a token budget, and what it cost.
pub type Trimmed {
  Trimmed(
    /// The retained prefix of the input.
    text: String,
    /// Its exact token count.
    tokens: Int,
    /// Its length in grapheme clusters.
    characters: Int,
    /// How many trailing pre-tokens were discarded.
    dropped_pieces: Int,
  )
}

/// Load the vocabulary. Seconds, once per handle, and by far the larger half
/// of the cost of a first call.
pub fn tokenizer() -> Tokenizer {
  Tokenizer(ranks: o200k_ranks.ranks())
}

/// The name of the encoding this package implements.
pub fn encoding_name() -> String {
  "o200k_base"
}

/// The exact number of `o200k_base` tokens in `text`.
///
/// The empty string is zero tokens. Special tokens such as `<|endoftext|>` are
/// not recognised and tokenize as ordinary text, which is what OpenAI calls
/// `encode_ordinary`.
pub fn count(tokenizer: Tokenizer, text: String) -> Int {
  list.fold(pretokenize.split(text), 0, fn(total, piece) {
    total + bpe.piece_token_count(tokenizer.ranks, piece)
  })
}

/// The exact `o200k_base` token ids for `text`.
pub fn encode(tokenizer: Tokenizer, text: String) -> List(Int) {
  list.flat_map(pretokenize.split(text), fn(piece) {
    bpe.encode_piece(tokenizer.ranks, piece)
  })
}

/// The longest prefix of `text` whose token count is at most `budget`.
///
/// Cuts happen at pre-token boundaries and never inside one, so the `tokens` of
/// a result always equal `count` of that result's `text`. The cost of that
/// guarantee is that the result can sit well under budget: the first pre-token
/// that does not fit stops the trim, so a leading pre-token larger than the
/// whole budget yields the empty string. A budget of zero or less always yields
/// an empty result.
pub fn trim_to_budget(
  tokenizer: Tokenizer,
  text: String,
  budget: Int,
) -> Trimmed {
  take(pretokenize.split(text), tokenizer, budget, 0, 0, [])
}

fn take(
  pieces: List(String),
  tokenizer: Tokenizer,
  budget: Int,
  used: Int,
  dropped: Int,
  kept: List(String),
) -> Trimmed {
  case pieces {
    [] -> finish(kept, used, dropped)
    [piece, ..rest] -> {
      let cost = bpe.piece_token_count(tokenizer.ranks, piece)
      case used + cost <= budget {
        True ->
          take(rest, tokenizer, budget, used + cost, dropped, [piece, ..kept])
        // Dropping this piece and continuing would join later pieces onto an
        // earlier prefix, so the result would no longer be a prefix at all.
        False -> finish(kept, used, dropped + 1 + list.length(rest))
      }
    }
  }
}

fn finish(kept: List(String), used: Int, dropped: Int) -> Trimmed {
  let text = string.join(list.reverse(kept), "")
  Trimmed(text, used, string.length(text), dropped)
}
