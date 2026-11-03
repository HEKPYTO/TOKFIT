# tokfit

[![CI](https://github.com/HEKPYTO/TOKFIT/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/HEKPYTO/TOKFIT/actions/workflows/ci.yml)
[![Hex](https://img.shields.io/hexpm/v/tokfit.svg)](https://hex.pm/packages/tokfit)
[![HexDocs](https://img.shields.io/badge/hexdocs-tokfit-blue.svg)](https://tokfit.hexdocs.pm/)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Count and trim text against OpenAI's `o200k_base` token budget, in pure
Gleam, on the Erlang and JavaScript runtimes, with no native code.

## What it does

`tokfit` answers one question exactly: how many tokens is this text, and
what is the largest prefix of it that fits the budget I was given?

- Pure Gleam. No NIFs, no FFI, no runtime downloads, no filesystem access.
- Byte-exact. Counts and token ids match OpenAI's `tiktoken` on ASCII and on
  CJK, Thai, Arabic, Hebrew, Devanagari, emoji, and combining marks, across a
  37-case committed corpus. The fixture pins both the count and the full id
  list for every case.
- Two runtimes. The same code and the same numbers on Erlang and on Node.

This is a careful port of a known algorithm, not a research result. BPE and
the `o200k_base` pattern belong to OpenAI; the Unicode category data belongs
to the Unicode Consortium. The work is in the exactness, the portability, and
the trim primitive.

## Install

```sh
gleam add tokfit
```

## Use

```gleam
import tokfit

pub fn main() {
  let tokenizer = tokfit.tokenizer()
  tokfit.count(tokenizer, "hello world")
  // -> 2
}
```

Build the tokenizer once and keep it. Loading the 199,998-entry vocabulary
dominates the first call, so a fresh one per call pays that every call.

## The API

| Function | Signature | What you get |
|---|---|---|
| `tokenizer` | `fn() -> Tokenizer` | The loaded vocabulary. Build it once. |
| `count` | `fn(Tokenizer, String) -> Int` | The exact token count. The empty string is 0. |
| `encode` | `fn(Tokenizer, String) -> List(Int)` | The exact token ids. |
| `trim_to_budget` | `fn(Tokenizer, String, Int) -> Trimmed` | The longest prefix that fits. |
| `encoding_name` | `fn() -> String` | `"o200k_base"`. |

`Trimmed` carries the retained `text`, its exact `tokens`, its `characters` in
grapheme clusters, and `dropped_pieces`.

`trim_to_budget` cuts at pre-token boundaries and never inside one, so its
`tokens` always equals `count` of its `text`. Adjacent pre-tokens can merge into
fewer tokens than their parts, so a piece is kept only while the exact count of
the joined prefix fits. The first pre-token that would exceed the budget ends
the prefix: a leading piece larger than the whole budget yields an empty string,
and the result can sit well under budget.

Special tokens are not recognised. `<|endoftext|>` tokenizes as ordinary text,
matching what OpenAI calls `encode_ordinary`.

## Command line

```sh
gleam run -m tokfit/cli -- count --text "hello world"
gleam run -m tokfit/cli -- trim --text "hello world" --budget 1
gleam run -m tokfit/cli -- encode --text "hello world"
```

Each prints a single line of JSON on stdout. Bad usage writes the usage string
to stderr and exits 1; stdout stays empty. The runtime's panic message and
stack trace surround the usage string, because there is no FFI and the process
cannot exit cleanly with code 1. The CLI builds one tokenizer per invocation,
so a shell loop over documents pays the load each time; call the library from a
long-lived process when throughput matters.

## What a call costs

Two costs, and they are not the same size. Loading the vocabulary is a one-off
measured at about 1.3 s on Erlang and 0.14 s on Node, which dominates a small
call. Tokenizing runs at roughly 1 s per megabyte of ASCII and 6 s per
megabyte of mixed CJK. Those numbers move between machines and runtimes, so
read them as orders of magnitude, not promises.

`tokfit/bench` prints the input size and the token count for a known workload
and loads the vocabulary once, so its wall clock is load plus tokenizing. No
CLI path loads and exits without tokenizing (`--help` stops before the
tokenizer is built), so the two costs cannot be separated from outside.

## Layout

| Path | What lives there |
|---|---|
| `src/tokfit.gleam` | The public API. The only module to import. |
| `src/tokfit/` | The CLI, the benchmark, and the internals. |
| `test/` | The corpus differential, the API and CLI suites, and the internals. |
| `scripts/` | The three generators, the checksum pin, and the lint and format hooks. |

## Licence

Apache-2.0. The Unicode tables and the OpenAI vocabulary carry their own
notices, collected in `LICENSE`.
