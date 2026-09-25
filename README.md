# gleam_tok

Count and trim text against OpenAI's `o200k_base` token budget, in pure
Gleam, on the Erlang and JavaScript runtimes, with no native code.

## What it does

`gleam_tok` answers one question exactly: how many tokens is this text, and
what is the largest prefix of it that fits the budget I was given?

- Pure Gleam. No NIFs, no FFI, no runtime downloads, no filesystem access.
- Byte-exact. Counts match OpenAI's `tiktoken` on ASCII and on CJK, Thai,
  Arabic, Hebrew, Devanagari, emoji, and combining marks.
- Two runtimes. The same code and the same numbers on Erlang and on Node.

This is a careful port of a known algorithm, not a research result. BPE and
the `o200k_base` pattern belong to OpenAI; the Unicode category data belongs
to the Unicode Consortium. The work is in the exactness, the portability, and
the trim primitive.

## Install

```sh
gleam add gleam_tok
```

## Use

```gleam
import gleam_tok

pub fn main() {
  gleam_tok.count("hello world")
  // -> 2
}
```

## Three functions

| Function | Signature | What you get |
|---|---|---|
| `count` | `fn(String) -> Int` | The exact token count. The empty string is 0. |
| `encode` | `fn(String) -> List(Int)` | The exact token ids. |
| `trim_to_budget` | `fn(String, Int) -> Trimmed` | The longest prefix that fits. |

`trim_to_budget` cuts at token boundaries and never inside one, so its
`tokens` always equals `count` of its `text`. The cost of that guarantee is
that the result can sit well under budget, and a budget at or below zero gives
an empty string. Both are deliberate: a prefix whose token count is not the
sum of its parts would be worse than no prefix at all.

Special tokens are not recognised. `<|endoftext|>` tokenizes as ordinary text,
matching what OpenAI calls `encode_ordinary`.

## Command line

```sh
gleam run -m gleam_tok/cli -- count --text "hello world"
gleam run -m gleam_tok/cli -- trim --text "hello world" --budget 1
gleam run -m gleam_tok/cli -- encode --text "hello world"
```

Each prints a single line of JSON on stdout. Bad usage prints the usage string
and exits 1.

## Licence

Apache-2.0.
