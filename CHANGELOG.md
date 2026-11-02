# Changelog

## 1.0.0

- Initial release.
- `count`, `encode`, and `trim_to_budget` for OpenAI's `o200k_base` encoding.
  Each takes a `Tokenizer` from `tokenizer/0`. Build one and keep it: the
  199,998-entry vocabulary is loaded once per tokenizer rather than once per
  call, which is the difference between one load and one load per document in
  a loop.
- Reverses design decision D7, which kept `count`, `encode`, and
  `trim_to_budget` stateless on the stated grounds that "Gleam module constants
  are evaluated once, so a handle buys nothing." The table is not a module
  constant. It is a `Dict` built by a function, so nothing was evaluated once
  and every call was reparsing 199,998 entries. Gleam has no module-level
  mutable state, and this package takes no target-specific dependency, so a
  value the caller holds is the only mechanism that pays for the load once
  without a NIF or a Node-only import.
- `tokfit` CLI with `count`, `trim`, and `encode`, emitting JSON.
- Pure Gleam on the Erlang and JavaScript runtimes. No NIFs, no FFI, no
  network access, and no filesystem access at run time.
- Byte-exact against OpenAI's `tiktoken` on a 30-case corpus covering ASCII,
  CJK, Thai, Arabic, Hebrew, Devanagari, emoji, and combining marks.
- `trim_to_budget` returns a real prefix: the first pre-token that does not fit
  stops the trim instead of being skipped for a cheaper later piece.
- `Trimmed.characters` is documented as grapheme clusters, its actual unit.
