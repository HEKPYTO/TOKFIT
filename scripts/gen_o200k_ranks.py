"""Generate src/tokfit/internal/o200k_ranks.gleam.

Fetches the pinned o200k_base.tiktoken, verifies its SHA-256 against
scripts/o200k.sha256, checks that ranks are contiguous and equal to the line
index, and writes a Gleam module holding the file verbatim as one string
constant. The base64 alphabet and the two separators are all literal-safe in a
Gleam string, so no escaping is needed.

Run manually when the pinned hash is intentionally bumped. Not part of the
build and not part of CI. The published package contains no script and makes
no network access.

    python3 scripts/gen_o200k_ranks.py            # download, verify, generate
    python3 scripts/gen_o200k_ranks.py FILE       # verify a local copy instead
"""

import hashlib
import sys
import urllib.request

URL = "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken"
SOURCE = "scripts/o200k.sha256"
TARGET = "src/tokfit/internal/o200k_ranks.gleam"
CHUNK = 40_000

TEMPLATE = '''//// GENERATED FILE. DO NOT EDIT.
//// Source: {url}
//// Regenerate with: python3 scripts/gen_o200k_ranks.py
////
//// The file is held verbatim and parsed on first use. A string constant is
//// one token to the compiler; a 200,000 element list constant is not, and
//// would make every build on both targets pay for it.
////
//// Base64 comes from `gleam/bit_array`, which has both a BEAM and a Node
//// implementation. No hand-written decoder, no dependency.

import gleam/bit_array
import gleam/dict.{{type Dict}}
import gleam/string

/// How many entries the vocabulary holds.
pub fn entry_count() -> Int {{
  {count}
}}

/// The o200k_base merge table: token bytes to rank.
///
/// The generator refuses to write a file whose rank is not its line index, so
/// the rank is the line number and parsing the second column would be work
/// whose result is already known.
pub fn ranks() -> Dict(BitArray, Int) {{
  insert_all(string.split(file, "\\n"), dict.new(), 0)
}}

fn insert_all(
  lines: List(String),
  entries: Dict(BitArray, Int),
  rank: Int,
) -> Dict(BitArray, Int) {{
  case lines {{
    // The file ends in a newline, so the split ends in one empty line.
    ["", ..] -> entries
    [] -> entries
    [line, ..rest] ->
      case string.split(line, " ") {{
        [token, _] ->
          case bit_array.base64_decode(token) {{
            Ok(bytes) ->
              insert_all(rest, dict.insert(entries, bytes, rank), rank + 1)
            Error(_) -> panic as "tokfit: malformed o200k_base vocabulary"
          }}
        _ -> panic as "tokfit: malformed o200k_base vocabulary"
      }}
  }}
}}

/// The file, verbatim.
const file = {body}
'''


def expected_hash() -> str:
    with open(SOURCE) as handle:
        return handle.read().split()[0]


def fetch(local: str | None) -> bytes:
    if local:
        with open(local, "rb") as handle:
            return handle.read()
    print(f"downloading {URL}")
    with urllib.request.urlopen(URL) as response:
        return response.read()


def main() -> int:
    want = expected_hash()
    data = fetch(sys.argv[1] if len(sys.argv) > 1 else None)
    got = hashlib.sha256(data).hexdigest()
    if got != want:
        print(f"hash mismatch\n  want {want}\n  got  {got}", file=sys.stderr)
        return 1
    text = data.decode("utf-8")
    lines = [line for line in text.split("\n") if line]
    for index, line in enumerate(lines):
        _, _, rank = line.partition(" ")
        if int(rank) != index:
            print(f"line {index} has rank {rank}", file=sys.stderr)
            return 1
    print(f"{len(lines)} entries, hash {got[:12]} ok")
    chunks = [text[i:i + CHUNK] for i in range(0, len(text), CHUNK)]
    body = '""\n' + "".join('  <> "' + chunk + '"\n' for chunk in chunks)
    # Numeric separators keep `gleam format` from rewriting the count.
    count = f"{len(lines):_}"
    with open(TARGET, "w") as handle:
        # The body already ends in a newline, so strip it back to one. An
        # extra blank line would make `gleam format --check` fail on a
        # freshly generated tree.
        rendered = TEMPLATE.format(url=URL, count=count, body=body)
        handle.write(rendered.rstrip("\n") + "\n")
    print(f"wrote {TARGET} in {len(chunks)} chunks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
