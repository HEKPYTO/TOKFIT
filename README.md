# gleam_tok

Count and trim text against OpenAI's `o200k_base` token budget, in pure
Gleam, on the Erlang and JavaScript runtimes, with no native code.

## What it does

`gleam_tok` answers one question exactly: how many tokens is this text, and
what is the largest prefix of it that fits the budget I was given?

- Pure Gleam. No NIFs, no FFI, no runtime downloads, no filesystem access.
- Byte-exact. Counts match OpenAI's `tiktoken` on ASCII and on CJK, Thai,
  Arabic, Hebrew, Devanagari, emoji, and combining marks, and on a 352 KB
  mixed-script input.
- Two runtimes. The same code and the same numbers on Erlang and on Node.

This is a careful port of a known algorithm, not a research result. BPE and
the `o200k_base` pattern belong to OpenAI; the Unicode category data belongs
to the Unicode Consortium. The work is in the exactness, the portability, and
the trim primitive.

## Use

```gleam
import gleam_tok

pub fn main() {
  let tokenizer = gleam_tok.tokenizer()
  gleam_tok.count(tokenizer, "hello world")
  // -> 2
}
```

Build the tokenizer once and keep it. Loading the 199,998-entry vocabulary
costs seconds and dominates the first call. A fresh one per call pays that
every call.

## The API

| Function | Signature | What you get |
|---|---|---|
| `tokenizer` | `fn() -> Tokenizer` | The loaded vocabulary. Build it once. |
| `count` | `fn(Tokenizer, String) -> Int` | The exact token count. The empty string is 0. |
| `encode` | `fn(Tokenizer, String) -> List(Int)` | The exact token ids. |
| `trim_to_budget` | `fn(Tokenizer, String, Int) -> Trimmed` | The longest prefix that fits. |
| `encoding_name` | `fn() -> String` | `"o200k_base"`. |

`Trimmed` carries the retained `text`, its exact `tokens`, its `characters` in
codepoints, and `dropped_pieces`.

`trim_to_budget` cuts at pre-token boundaries and never inside one, so its
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
and exits 1. The CLI builds one tokenizer per invocation, so a shell loop over
documents pays the load each time; call the library from a long-lived process
when throughput matters.

## What a call costs

Two costs, and they are not the same size. Loading the vocabulary is a one-off
of seconds per tokenizer. Tokenizing is a fixed rate per byte on top. The
absolute numbers move a lot between machines and between Erlang and Node, so
this page does not quote them. `gleam_tok/bench` prints the input size and the
token count for a known workload; time it and you have both costs for your
machine:

```sh
time gleam run -m gleam_tok/bench
time gleam run -m gleam_tok/cli -- --help
```

The difference between those two is the load. The rest of the benchmark's wall
clock is tokenizing.

## Layout

| Path | What lives there |
|---|---|
| `src/gleam_tok.gleam` | The public API. The only module to import. |
| `src/gleam_tok/` | The CLI, the benchmark, and the internals. |
| `test/` | The corpus differential, the API and CLI suites, and the internals. |
| `scripts/` | The three generators and the lint and format hooks. |

## Licence

Apache-2.0.
