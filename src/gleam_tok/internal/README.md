# internal

Not public API. Hidden from generated docs by `internal_modules` in
`gleam.toml`. Nothing here carries a compatibility promise; only `gleam_tok`
does.

| Module | Responsibility |
|---|---|
| `unicode_categories` | Generated. Unicode general categories and `White_Space`, as a sorted range table plus a forward-cursor classifier. |
| `pretokenize` | The seven branches of the `o200k_base` pattern, written out as explicit matchers. |
| `bpe` | The merge loop, over `Dict(BitArray, Int)`. |
| `o200k_ranks` | Generated. The 199,998-entry merge table, held as a string and parsed on use. |

Base64 decoding is `bit_array.base64_decode/1` from `gleam_stdlib`, not a
module of ours.

## Why there is no regex dependency

The `o200k_base` pattern uses lookahead, and the `cl100k_base` variant uses
possessive quantifiers that neither ECMAScript nor PCRE provides. There is no
pure-Gleam regex engine on Hex: `gleam_regexp` is a PCRE binding, which would
make the "no native code" promise contingent on a NIF installing cleanly. A
hand-written matcher is smaller, has no native code, and fails in a way a test
can point at.

## Why classification uses a cursor

`category_list` resolves a whole list of codepoints in one left-to-right pass
with a forward-only cursor. A binary search per codepoint would be O(n),
because Gleam lists cannot be indexed: `list.at` walks from the front. Reading
text in order means the cursor only moves forward, which makes classification
amortised O(1) per codepoint.

## Why every list is built by accumulating and reversing

Gleam's JavaScript backend optimises tail calls, so a tail-recursive loop runs
in constant stack. Building a list as `[x, ..recurse(rest)]` does not, and one
non-tail-recursive list builder per input character is enough to run Node out
of stack on a few hundred kilobytes of text. Every list in these two modules is
therefore built by a tail-recursive loop into a reversed accumulator and
flipped once with `list.reverse`. `splits_text_longer_than_the_javascript_stack_test`
and `merges_a_piece_longer_than_the_javascript_stack_test` are the guards; both
pass on Erlang and both used to crash on Node.

## Regenerating the generated modules

```sh
python3 scripts/gen_unicode_categories.py
python3 scripts/gen_o200k_ranks.py
```

Both are manual. Neither runs in the build or in CI. The published package
contains no script and makes no network access.
