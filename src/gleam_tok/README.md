# gleam_tok

The public API, the CLI, and the benchmark. `../gleam_tok.gleam` is the only
module a user needs; this directory holds the runnable parts.

## `gleam_tok`

| Function | Signature | Returns |
|---|---|---|
| `tokenizer` | `fn() -> Tokenizer` | The loaded vocabulary. Build it once and keep it. |
| `count` | `fn(Tokenizer, String) -> Int` | The exact `o200k_base` token count. The empty string is 0. |
| `encode` | `fn(Tokenizer, String) -> List(Int)` | The exact token ids. |
| `trim_to_budget` | `fn(Tokenizer, String, Int) -> Trimmed` | The longest prefix that fits, cut at pre-token boundaries. |
| `encoding_name` | `fn() -> String` | `"o200k_base"`. |

`Trimmed` carries `text`, its exact `tokens`, its `characters` in codepoints,
and `dropped_pieces`. `Tokenizer` is opaque: the only way to get one is
`tokenizer/0`, and the only way to use one is to pass it to the three functions
above.

Special tokens are not recognised. `<|endoftext|>` tokenizes as ordinary text,
matching what OpenAI calls `encode_ordinary`.

`trim_to_budget` never cuts inside a pre-token, so its `tokens` always equals
`count` of its `text`. The price is that the result can sit well under budget,
and a budget at or below zero gives an empty string. Both are deliberate: a
prefix whose token count is not the sum of its parts would be worse than no
prefix at all.

## Why there is a handle

`o200k_ranks.ranks()` parses all 199,998 vocabulary entries. That is about
1.1 s on Erlang and 0.2 s on Node, three orders of magnitude more than the
tokenizing it feeds.

Gleam has no module-level mutable state, and this package takes no
target-specific dependency, so a plain function cannot hold the parsed table
between calls. `gleam/erlang/process` and `gleam_javascript` would each do it
for one target and neither exists for the other, and both would put a NIF or a
Node-only import behind the promise of pure, portable Gleam. A value the caller
holds is the one mechanism that works on both targets without a dependency.

So `count/2` and friends take the handle. A caller that counts one document
pays the load once either way. A caller that loops pays it once instead of
once per document, which is the difference between 0.2 s and 0.2 s times the
corpus.

## What a call costs

Loading the vocabulary is about 1.1 s on Erlang and 0.2 s on Node, once per
tokenizer. Tokenizing runs at roughly 460 KB/s on Erlang and 270 KB/s on Node.

## `gleam_tok/cli`

```sh
gleam run -m gleam_tok/cli -- count --text TEXT
gleam run -m gleam_tok/cli -- trim --text TEXT --budget N
gleam run -m gleam_tok/cli -- encode --text TEXT
```

One line of JSON on stdout. Bad usage prints the usage string and exits 1.
Every exit is either 0 or 1, because there is no OTP process and no FFI, so
finer-grained codes are not available and were not worth the machinery.

`try_run/1` is the whole command as a pure function over an argument list, so
every line above is testable without a process. Its argument is
`argv.load().arguments`, which has the program name already removed, so the
command is the first element.

## `gleam_tok/bench`

```sh
time gleam run -m gleam_tok/bench
```

Prints the input size and the total token count. It loads the vocabulary once
and tokenizes the whole input in one pass, so the wall clock splits into the
fixed load and the throughput you actually want. Both runtimes report the same
count, which is the cheapest large-input cross-target check this project has.
