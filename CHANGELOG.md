# Changelog

## 1.0.0

- Initial release.
- `count`, `encode`, and `trim_to_budget` for OpenAI's `o200k_base` encoding.
- `gleam-tok` CLI with `count`, `trim`, and `encode`, emitting JSON.
- Pure Gleam on the Erlang and JavaScript runtimes. No NIFs, no FFI, no
  network access, and no filesystem access at run time.
- Byte-exact against OpenAI's `tiktoken` on a 30-case corpus covering ASCII,
  CJK, Thai, Arabic, Hebrew, Devanagari, emoji, and combining marks, and on a
  352 KB mixed-script input.
