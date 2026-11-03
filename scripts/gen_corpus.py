"""Generate test/fixtures/corpus.gleam from real tiktoken.

Run manually when the corpus changes. Requires Python, the tiktoken package
and the Gleam toolchain. CI does not run this; CI reads the committed fixture.

    python3 -m pip install tiktoken
    python3 scripts/gen_corpus.py
"""

import subprocess
import sys
from pathlib import Path

import tiktoken

TARGET = "test/fixtures/corpus.gleam"

CASES = [
    "",
    "hello world",
    "Hello, world!",
    "The quick brown fox jumps over the lazy dog.",
    "  leading and trailing spaces   ",
    "\n\nmultiple\nnewlines\r\n\r\nhere\n",
    "\t\ttabs and \x20 spaces\x20\x20\x20",
    "1234567890",
    "1 2 3 4 5 6 7 8 9 0",
    "3.14159 and 1,000,000 and 0x1F",
    "don't can't it'll we've I'm you'll he'd",
    "https://example.com/path?q=1&r=2#frag",
    "def count(text: String) -> Int { 1 }",
    "SELECT * FROM users WHERE id = ?;",
    '{"json": [true, false, null]}',
    "日本語のテキストです",
    "中文测试字符串",
    "ภาษาไทย",
    "مرحبا بالعالم",
    "שלום עולם",
    "नमस्ते दुनिया",
    "emoji \U0001f600\U0001f389 and math ∑∫≈",
    # Decomposed, not precomposed: a combining mark after a lowercase Latin
    # letter. The Devanagari case already covers a mark after a LetterOther,
    # which is in both the upperish and the lowering class, so it does not
    # exercise a mark that only the lowering class accepts.
    "combining a\u0301e\u0300o\u0308u\u0303n\u0301",
    "nbsp here and ideographic　space",
    "mixed 日本語 and English and 123",
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "one two three four five six seven eight nine ten",
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    "line one\nline two\nline three\nline four\nline five",
    "Привет, мир",
    # An apostrophe with no contraction suffix is not part of the word: the
    # group is optional, so it must not be consumed on its own.
    "a'x",
    "C'}",
    "a'\n",
    # A leading combining mark is not the optional character of branch 1 or 2;
    # it belongs to the upperish run, so it stays attached to what follows.
    "\u0301\"a",
    "\u0301's",
]

ESCAPES = {
    "\\": "\\\\",
    '"': '\\"',
    "\n": "\\n",
    "\r": "\\r",
    "\t": "\\t",
}


def gleam_string(value: str) -> str:
    out = []
    for char in value:
        if char in ESCAPES:
            out.append(ESCAPES[char])
        else:
            out.append(f"\\u{{{ord(char):x}}}")
    return '"' + "".join(out) + '"'


def main() -> int:
    encoding = tiktoken.get_encoding("o200k_base")
    lines = [
        "//// GENERATED FILE. DO NOT EDIT.",
        "//// Expected token ids from OpenAI tiktoken's o200k_base encoding.",
        "//// Regenerate with: python3 scripts/gen_corpus.py",
        "",
        "/// One input, and the token ids and count real tiktoken gives it.",
        "pub type CorpusCase {",
        "  CorpusCase(text: String, tokens: Int, ids: List(Int))",
        "}",
        "",
        "/// The corpus. Any mismatch against `tokfit.encode` or `tokfit.count`",
        "/// stops the project.",
        "pub const cases: List(CorpusCase) = [",
    ]
    for text in CASES:
        ids = encoding.encode_ordinary(text)
        rendered = ", ".join(str(id) for id in ids)
        lines.append(
            f"  CorpusCase(text: {gleam_string(text)}, tokens: {len(ids)},"
            f" ids: [{rendered}]),"
        )
    lines.append("]")
    Path(TARGET).parent.mkdir(parents=True, exist_ok=True)
    with open(TARGET, "w") as handle:
        handle.write("\n".join(lines) + "\n")
    # One escaped codepoint per character puts most cases past the line length
    # limit. Let the formatter decide the wrapping instead of guessing at it.
    subprocess.run(["gleam", "format", TARGET], check=True, capture_output=True)
    print(f"wrote {TARGET}: {len(CASES)} cases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
