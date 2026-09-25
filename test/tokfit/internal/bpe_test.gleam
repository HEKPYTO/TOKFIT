import gleam/bit_array
import gleam/dict
import tokfit/internal/bpe
import gleeunit

pub fn main() {
  gleeunit.main()
}

/// The educational example from tiktoken's own documentation.
fn toy_ranks() -> bpe.Ranks {
  dict.from_list([
    #(bit_array.from_string("h"), 0),
    #(bit_array.from_string("e"), 1),
    #(bit_array.from_string("l"), 2),
    #(bit_array.from_string("o"), 3),
    #(bit_array.from_string("he"), 256),
    #(bit_array.from_string("ll"), 257),
  ])
}

pub fn single_byte_pieces_become_single_tokens_test() {
  let assert [0] = bpe.encode_piece(toy_ranks(), "h")
  let assert [3] = bpe.encode_piece(toy_ranks(), "o")
}

pub fn known_piece_is_one_token_test() {
  let assert [256] = bpe.encode_piece(toy_ranks(), "he")
  let assert [257] = bpe.encode_piece(toy_ranks(), "ll")
}

pub fn merges_by_rank_test() {
  // h e l l o. (h,e) is rank 256, (l,l) is rank 257, so (h,e) merges first.
  // The result he l l o has no further mergeable adjacent pair.
  let assert [256, 257, 3] = bpe.encode_piece(toy_ranks(), "hello")
}

pub fn merges_a_pair_at_an_odd_index_test() {
  // a b c, with only (b,c) in the table. (b,c) starts at index 1, so a matcher
  // that only looked at disjoint pairs would report three tokens.
  let ranks =
    dict.from_list([
      #(bit_array.from_string("a"), 0),
      #(bit_array.from_string("b"), 1),
      #(bit_array.from_string("c"), 2),
      #(bit_array.from_string("bc"), 100),
    ])
  let assert [0, 100] = bpe.encode_piece(ranks, "abc")
}

pub fn merges_every_occurrence_of_the_best_pair_test() {
  // a a a, with (a,a) in the table. Both occurrences merge, leaving one
  // symbol that cannot merge with itself again.
  let ranks =
    dict.from_list([
      #(bit_array.from_string("a"), 0),
      #(bit_array.from_string("aa"), 100),
    ])
  let assert [100, 0] = bpe.encode_piece(ranks, "aaa")
}

pub fn unknown_piece_falls_back_to_bytes_test() {
  // "he!" is not in the table. (h,e) is rank 256 and (e,!) is absent, so the
  // merge happens and `!` has no rank of its own and falls back to 0.
  let assert [256, 0] = bpe.encode_piece(toy_ranks(), "he!")
}

pub fn empty_piece_is_no_tokens_test() {
  let assert [] = bpe.encode_piece(toy_ranks(), "")
}

pub fn multibyte_piece_is_byte_wise_test() {
  // Neither UTF-8 byte of "é" is in the toy table, so both fall back to 0.
  let assert [0, 0] = bpe.encode_piece(toy_ranks(), "é")
}

pub fn piece_token_count_matches_encode_length_test() {
  let ranks = toy_ranks()
  let assert 3 = bpe.piece_token_count(ranks, "hello")
  let assert 0 = bpe.piece_token_count(ranks, "")
}

pub fn encode_piece_bytes_matches_encode_piece_test() {
  let ranks = toy_ranks()
  let assert True =
    bpe.encode_piece(ranks, "hello")
    == bpe.encode_piece_bytes(ranks, bit_array.from_string("hello"))
}
