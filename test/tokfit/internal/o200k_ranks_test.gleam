import gleam/dict
import tokfit/internal/o200k_ranks

/// The real file's first five lines are `IQ== 0` through `JQ== 4`, which decode
/// to the single bytes for `!`, `"`, `#`, `$`, and `%`. A parse that dropped or
/// reordered a line would not produce exactly this.
pub fn first_ranks_are_single_bytes_test() {
  let ranks = o200k_ranks.ranks()
  let assert Ok(0) = dict.get(ranks, <<0x21>>)
  let assert Ok(1) = dict.get(ranks, <<0x22>>)
  let assert Ok(2) = dict.get(ranks, <<0x23>>)
  let assert Ok(3) = dict.get(ranks, <<0x24>>)
  let assert Ok(4) = dict.get(ranks, <<0x25>>)
}

/// The table must hold every line of the file, and the last of them must carry
/// the last rank. The size is the half that catches a truncated parse; the last
/// rank is the half that catches a shifted one. `IGNvY29z 199997` is `" cocos"`,
/// a space and five lowercase letters.
pub fn every_line_is_parsed_and_the_last_rank_is_199997_test() {
  let ranks = o200k_ranks.ranks()
  let assert 199_998 = dict.size(ranks)
  let assert Ok(199_997) = dict.get(ranks, <<" cocos":utf8>>)
}
