# gleam_tok

The public API, the CLI, and the benchmark. `../gleam_tok.gleam` is the only
module a user needs; this directory holds the runnable parts.

## `gleam_tok`

| Function | Signature | Returns |
|---|---|---|
| `count` | `fn(String) -> Int` | The exact `o200k_base` token count. The empty string is 0. |
| `encode` | `fn(String) -> List(Int)` | The exact token ids. |
| `trim_to_budget` | `fn(String, Int) -> Trimmed` | The longest prefix that fits, cut at pre-token boundaries. |
| `encoding_name` | `fn() -> String` | `"o200k_base"`. |

`Trimmed` carries `text`, its exact `tokens`, its `characters` in codepoints,
and `dropped_pieces`. That is the whole public surface: five items, no handle,
no encoder to configure.

Special tokens are not recognised. `<|endoftext|>` tokenizes as ordinary text,
matching what OpenAI calls `encode_ordinary`.

`trim_to_budget` never cuts inside a pre-token, so its `tokens` always equals
`count` of its `text`. The price is that the result can sit well under budget,
and a budget at or below zero gives an empty string. Both are deliberate: a
prefix whose token count is not the sum of its parts would be worse than no
prefix at all.

## What a call costs

`o200k_ranks.ranks()` re-parses all 199,998 vocabulary entries on every call.
That is about 1.1 s on Erlang and 0.45 s on Node, and it dominates the first
call by three orders of magnitude. Tokenizing itself runs at roughly
460 KB/s on Erlang and 270 KB/s on Node.

So a loop of `count` calls over a large corpus pays that price every
iteration. That is a known cost with a known fix and no fix applied: parsing
once and holding the table needs either a public handle or a memoised module
value, and both change the public surface. If it bites, that decision is the
next piece of work, not a silent workaround.

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

Prints the input size and the total token count. It builds the merge table
once and tokenizes the whole input in one pass, so the wall clock splits into
the fixed table parse and the throughput you actually want. Both runtimes
report the same count, which is the cheapest large-input cross-target check
this project has.
