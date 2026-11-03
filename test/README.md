# test

| File | Tests | What it proves |
|---|---:|---|
| `corpus_test.gleam` | 2 | The differential against real tiktoken: expected counts and token ids, zero mismatches or the project stops. |
| `tokfit_test.gleam` | 18 | The public API's own guarantees: `trim_to_budget` returns a prefix, is self-consistent, never exceeds its budget, and is monotone; special-token literals stay ordinary text. |
| `tokfit/internal/o200k_ranks_test.gleam` | 2 | The vocabulary parse holds all 199,998 lines and the first and last ranks are the real ones. |
| `tokfit/cli_test.gleam` | 18 | One line of JSON per command, every dangerous character escaped, bad usage refused. |
| `tokfit/internal/pretokenize_test.gleam` | 18 | Every branch of the `o200k_base` pattern against hand-derived splits, plus a round trip and a stack-depth guard. |
| `tokfit/internal/bpe_test.gleam` | 11 | The merge loop against the toy rank table from tiktoken's own documentation, plus a stack-depth guard. |
| `tokfit/internal/unicode_categories_test.gleam` | 13 | Category lookup at both ends of a range, one below a range start, and the range-table classifier. |
| `fixtures/corpus.gleam` | — | Generated. Expected counts and token ids from OpenAI's `o200k_base`, imported directly by `corpus_test.gleam`. |
| **Total** | **82** | |

Run one target with `gleam test --target erlang` or
`gleam test --target javascript`. The JavaScript run is not a formality: the
two stack-depth tests exist because the Erlang target passed while Node ran
out of stack.

## Why the corpus differential is the important one

Every other suite checks this implementation against itself. Only
`corpus_test.gleam` checks it against OpenAI, and it is the only one that can
fail for a reason no other test would catch.

The fixture is committed on purpose. CI must be able to prove exactness with
no network and no Python. Regenerate it with `python3 scripts/gen_corpus.py`
after installing `tiktoken`. Never hand-edit it: if a count or an id is wrong,
the implementation is wrong.

## Why the corpus test builds one tokenizer

Loading the 199,998-entry table is the expensive part of a run: about 1.3 s on
Erlang and 0.14 s on Node here. The 37 cases that each built their own handle
would pay that 37 times over. One tokenizer at the top of the test and
`tokfit.count` per case keeps the differential on the public path, which is the
path worth differentiating.

The other suites do pay per test, because `gleeunit` has no setup hook and
sharing one handle across tests would couple failures that are currently
independent. `tokfit_test.gleam` therefore loads the table once per test.
That is the cost of not having a fixture, and it is CI time only.
