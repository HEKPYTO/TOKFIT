# test

| File | Tests | What it proves |
|---|---:|---|
| `corpus_test.gleam` | 2 | The differential against real tiktoken. Zero mismatches or the project stops. |
| `gleam_tok_test.gleam` | 13 | The public API's own guarantees: `trim_to_budget` never exceeds its budget, is self-consistent, and is monotone. |
| `gleam_tok/cli_test.gleam` | 17 | One line of JSON per command, every dangerous character escaped, bad usage refused. |
| `gleam_tok/internal/pretokenize_test.gleam` | 15 | Every branch of the `o200k_base` pattern against hand-derived splits, plus a round trip and a stack-depth guard. |
| `gleam_tok/internal/bpe_test.gleam` | 11 | The merge loop against the toy rank table from tiktoken's own documentation, plus a stack-depth guard. |
| `gleam_tok/internal/unicode_categories_test.gleam` | 12 | Category lookup at both ends of five ranges, and the forward-cursor classifier. |
| `corpus.gleam` | — | A thin adapter from the fixture to named fields. |
| `fixtures/corpus.gleam` | — | Generated. Expected counts from OpenAI's `o200k_base`. |

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
after installing `tiktoken`. Never hand-edit it: if a count is wrong, the
implementation is wrong.

## Why the corpus test does not call `count`

`o200k_ranks.ranks()` re-parses all 199,998 entries on every call, about 1.1 s
on Erlang. Thirty calls to the public `count` would spend thirty seconds
re-parsing one table. The test builds the table once and folds the pre-tokens
itself. The public function is a three-line wrapper over exactly that fold, and
`gleam_tok_test.gleam` exercises it directly.
