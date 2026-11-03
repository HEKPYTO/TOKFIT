# tokfit

The public API, the CLI, and the benchmark. `../tokfit.gleam` is the only
module a user needs; this directory holds the runnable parts.

## `tokfit`

| Function | Signature | Returns |
|---|---|---|
| `tokenizer` | `fn() -> Tokenizer` | The loaded vocabulary. Build it once and keep it. |
| `count` | `fn(Tokenizer, String) -> Int` | The exact `o200k_base` token count. The empty string is 0. |
| `encode` | `fn(Tokenizer, String) -> List(Int)` | The exact token ids. |
| `trim_to_budget` | `fn(Tokenizer, String, Int) -> Trimmed` | The longest prefix that fits, cut at pre-token boundaries. |
| `encoding_name` | `fn() -> String` | `"o200k_base"`. |

`Trimmed` carries `text`, its exact `tokens`, its `characters` in grapheme
clusters, and `dropped_pieces`. `Tokenizer` is opaque: the only way to get one is
`tokenizer/0`, and the only way to use one is to pass it to the three functions
above.

Special tokens are not recognised. `<|endoftext|>` tokenizes as ordinary text,
matching what OpenAI calls `encode_ordinary`.

`trim_to_budget` never cuts inside a pre-token, so its `tokens` always equals
`count` of its `text`. Adjacent pre-tokens can merge into fewer tokens than
their parts, so a piece is kept only while the exact count of the joined prefix
fits. The first pre-token that would exceed the budget ends the prefix, so a
leading piece larger than the budget gives an empty string and the result can
sit well under budget.

## Why there is a handle

`o200k_ranks.ranks()` parses all 199,998 vocabulary entries, which dominates
the first call and dwarfs the tokenizing it feeds.

Gleam has no module-level mutable state, and this package takes no
target-specific dependency, so a plain function cannot hold the parsed table
between calls. `gleam/erlang/process` and `gleam_javascript` would each do it
for one target and neither exists for the other, and both would put a NIF or a
Node-only import behind the promise of pure, portable Gleam. A value the caller
holds is the one mechanism that works on both targets without a dependency.

So `count/2` and friends take the handle. A caller that counts one document
pays the load once either way. A caller that loops pays it once instead of
once per document.

## What a call costs

Loading the vocabulary is a one-off measured at about 1.3 s on Erlang and
0.14 s on Node. Tokenizing runs at roughly 1 s per megabyte of ASCII and 6 s
per megabyte of mixed CJK. Those figures move between machines and runtimes,
so read them as orders of magnitude. `tokfit/bench` prints the input size and
token count for a known workload and loads once, so its wall clock is load
plus tokenizing. No CLI path loads and exits without tokenizing (`--help`
stops before the tokenizer is built), so the two costs cannot be separated
from outside.

## `tokfit/cli`

```sh
gleam run -m tokfit/cli -- count --text TEXT
gleam run -m tokfit/cli -- trim --text TEXT --budget N
gleam run -m tokfit/cli -- encode --text TEXT
```

One line of JSON on stdout. Bad usage leaves stdout empty, writes the usage
string to stderr, and exits 1; the runtime's panic message and stack trace are
part of that stderr, because there is no FFI and the process cannot exit
cleanly with code 1. Every exit is either 0 or 1, so finer-grained codes are
not available and were not worth the machinery.

`try_run/1` is the whole command as a pure function over an argument list, so
every line above is testable without a process. Its argument is
`argv.load().arguments`, which has the program name already removed, so the
command is the first element.

## `tokfit/bench`

```sh
time gleam run -m tokfit/bench
```

Prints the input size and the total token count. It loads the vocabulary once
and tokenizes the whole input in one pass, so its wall clock is the fixed load
plus the tokenizing; no CLI path loads without tokenizing, so the two cannot
be split from outside. Both runtimes report the same count, which is the
cheapest large-input cross-target check this project has.
