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
`count` of its `text`. The first pre-token that does not fit ends the prefix,
so a leading piece larger than the budget gives an empty string and the result
can sit well under budget. Both are deliberate: a prefix whose token count is
not the sum of its parts would be worse than no prefix at all.

## Why there is a handle

`o200k_ranks.ranks()` parses all 199,998 vocabulary entries, which costs
seconds and dwarfs the tokenizing it feeds.

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

Loading the vocabulary is seconds, once per tokenizer. Tokenizing is a fixed
rate per byte on top. Neither figure is quoted here: they move too much between
machines and runtimes to be worth publishing, and a wrong number is worse than
none. `tokfit/bench` prints the input size and token count for a known
workload. Time it, and time `tokfit/cli -- --help`; the difference is the
load and the remainder is tokenizing.

## `tokfit/cli`

```sh
gleam run -m tokfit/cli -- count --text TEXT
gleam run -m tokfit/cli -- trim --text TEXT --budget N
gleam run -m tokfit/cli -- encode --text TEXT
```

One line of JSON on stdout. Bad usage prints the usage string and exits 1.
Every exit is either 0 or 1, because there is no OTP process and no FFI, so
finer-grained codes are not available and were not worth the machinery.

`try_run/1` is the whole command as a pure function over an argument list, so
every line above is testable without a process. Its argument is
`argv.load().arguments`, which has the program name already removed, so the
command is the first element.

## `tokfit/bench`

```sh
time gleam run -m tokfit/bench
```

Prints the input size and the total token count. It loads the vocabulary once
and tokenizes the whole input in one pass, so the wall clock splits into the
fixed load and the throughput you actually want. Both runtimes report the same
count, which is the cheapest large-input cross-target check this project has.
