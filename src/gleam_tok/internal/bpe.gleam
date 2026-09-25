//// Byte-level BPE merging.
////
//// Repeatedly merge the adjacent symbol pair with the lowest rank in the
//// rank table, merging every non-overlapping occurrence of that pair, until no
//// adjacent pair has a rank. A piece that is itself in the table short-circuits
//// to one token.

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}

/// Token bytes to merge rank.
pub type Ranks =
  Dict(BitArray, Int)

/// The token ids for one pre-token.
pub fn encode_piece(ranks: Ranks, piece: String) -> List(Int) {
  encode_piece_bytes(ranks, bit_array.from_string(piece))
}

/// How many tokens one pre-token is worth.
pub fn piece_token_count(ranks: Ranks, piece: String) -> Int {
  list.length(encode_piece(ranks, piece))
}

/// The token ids for one run of bytes.
pub fn encode_piece_bytes(ranks: Ranks, bytes: BitArray) -> List(Int) {
  case dict.get(ranks, bytes) {
    Ok(rank) -> [rank]
    Error(Nil) -> merge_all(ranks, split_bytes(bytes, []))
  }
}

fn split_bytes(input: BitArray, acc: List(BitArray)) -> List(BitArray) {
  case input {
    <<byte:8, rest:bits>> -> {
      let one = <<byte>>
      split_bytes(rest, [one, ..acc])
    }
    _ -> list.reverse(acc)
  }
}

fn merge_all(ranks: Ranks, symbols: List(BitArray)) -> List(Int) {
  case best_pair(ranks, symbols) {
    None -> ranks_of(ranks, symbols, [])
    Some(#(left, right, _)) ->
      merge_all(ranks, merge_pair(symbols, left, right))
  }
}

/// The fallback of 0 cannot happen against the real table, where every single
/// byte has a rank. It is here so a partial table does not crash.
fn ranks_of(
  ranks: Ranks,
  symbols: List(BitArray),
  acc: List(Int),
) -> List(Int) {
  case symbols {
    [] -> list.reverse(acc)
    [symbol, ..rest] ->
      case dict.get(ranks, symbol) {
        Ok(rank) -> ranks_of(ranks, rest, [rank, ..acc])
        Error(Nil) -> ranks_of(ranks, rest, [0, ..acc])
      }
  }
}

// ponytail: best_pair rescans every adjacent pair on each merge, so a piece is
// O(n^2) in its own length. Pre-tokens are a few dozen bytes at most, so this
// is fine. If a pre-token ever grows, key a priority queue on rank instead.

/// The mergeable adjacent pair with the lowest rank, and that rank. Leftmost
/// wins a tie, which is what the reference implementation's strict `<` does.
///
/// Every adjacent position is considered, not every other one. Taking only
/// disjoint pairs misses a merge that starts at an odd index, which is a
/// different token count.
fn best_pair(
  ranks: Ranks,
  symbols: List(BitArray),
) -> Option(#(BitArray, BitArray, Int)) {
  case symbols {
    [first, second, ..rest] -> scan_pairs(ranks, first, second, rest, None)
    _ -> None
  }
}

/// Walk the remaining symbols, carrying the symbol before the current one.
fn scan_pairs(
  ranks: Ranks,
  previous: BitArray,
  current: BitArray,
  rest: List(BitArray),
  best: Option(#(BitArray, BitArray, Int)),
) -> Option(#(BitArray, BitArray, Int)) {
  let best = consider(ranks, previous, current, best)
  case rest {
    [next, ..tail] -> scan_pairs(ranks, current, next, tail, best)
    [] -> best
  }
}

fn consider(
  ranks: Ranks,
  left: BitArray,
  right: BitArray,
  best: Option(#(BitArray, BitArray, Int)),
) -> Option(#(BitArray, BitArray, Int)) {
  case dict.get(ranks, bit_array.append(left, right)) {
    Error(Nil) -> best
    Ok(rank) ->
      case best {
        None -> Some(#(left, right, rank))
        Some(#(_, _, best_rank)) ->
          case rank < best_rank {
            True -> Some(#(left, right, rank))
            False -> best
          }
      }
  }
}

/// Replace every non-overlapping occurrence of the `left`+`right` pair with the
/// joined symbol.
fn merge_pair(
  symbols: List(BitArray),
  left: BitArray,
  right: BitArray,
) -> List(BitArray) {
  case symbols {
    [] -> []
    [a, b, ..rest] ->
      case a == left && b == right {
        True -> [bit_array.append(a, b), ..merge_pair(rest, left, right)]
        False -> [a, ..merge_pair([b, ..rest], left, right)]
      }
    _ -> symbols
  }
}
