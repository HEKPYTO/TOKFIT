//// The `gleam-tok` command.
////
//// Emits a single line of JSON on stdout. Bad usage prints the usage string
//// and exits 1. There is no OTP process and no FFI, so every failure exits 1
//// and no finer-grained codes are available; they are not worth the
//// machinery they would need.

import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam_tok

const usage_string = "usage: gleam-tok count --text TEXT
  |   gleam-tok trim --text TEXT --budget N
  |   gleam-tok encode --text TEXT"

/// The usage string, also what `--help` prints.
pub fn usage() -> String {
  usage_string
}

/// Entry point.
pub fn main() -> Nil {
  case try_run(argv.load().arguments) {
    Ok(json) -> io.println(json)
    Error(message) -> panic as message
  }
}

/// Run one command over `arguments`, returning the JSON line or an error
/// message.
///
/// `arguments` is `argv.load().arguments`, which is the command line with the
/// program name already removed, so the command is the first element.
pub fn try_run(arguments: List(String)) -> Result(String, String) {
  case arguments {
    ["count", ..rest] -> with_text(rest, count_json)
    ["trim", ..rest] -> trim_command(rest)
    ["encode", ..rest] -> with_text(rest, encode_json)
    ["--help"] -> Ok(usage_string)
    ["-h"] -> Ok(usage_string)
    _ -> Error(usage_string)
  }
}

fn trim_command(rest: List(String)) -> Result(String, String) {
  case flags(rest) {
    Ok(#(text, budget)) -> Ok(trim_json(text, budget))
    Error(Nil) -> Error(usage_string)
  }
}

fn with_text(
  arguments: List(String),
  build: fn(String) -> String,
) -> Result(String, String) {
  case flags(arguments) {
    Ok(#(text, _)) -> Ok(build(text))
    Error(Nil) -> Error(usage_string)
  }
}

/// `--text TEXT` and an optional `--budget N`.
fn flags(arguments: List(String)) -> Result(#(String, Int), Nil) {
  case arguments {
    ["--text", text, ..rest] ->
      case rest {
        [] -> Ok(#(text, 0))
        ["--budget", budget, ..more] ->
          case more {
            [] ->
              case int.parse(budget) {
                Ok(value) -> Ok(#(text, value))
                Error(_) -> Error(Nil)
              }
            _ -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn count_json(text: String) -> String {
  object([
    string_field("encoding", gleam_tok.encoding_name()),
    number_field("tokens", gleam_tok.count(text)),
    number_field("characters", string.length(text)),
    number_field("bytes", string.byte_size(text)),
  ])
}

fn trim_json(text: String, budget: Int) -> String {
  let trimmed = gleam_tok.trim_to_budget(text, budget)
  object([
    string_field("encoding", gleam_tok.encoding_name()),
    number_field("budget", budget),
    number_field("tokens", trimmed.tokens),
    number_field("characters", trimmed.characters),
    number_field("dropped_pieces", trimmed.dropped_pieces),
    string_field("text", trimmed.text),
  ])
}

fn encode_json(text: String) -> String {
  let ids =
    text
    |> gleam_tok.encode()
    |> list.map(int.to_string)
    |> string.join(",")
  object([
    string_field("encoding", gleam_tok.encoding_name()),
    "\"tokens\":[" <> ids <> "]",
  ])
}

fn object(fields: List(String)) -> String {
  "{" <> string.join(fields, ",") <> "}"
}

fn number_field(name: String, value: Int) -> String {
  "\"" <> name <> "\":" <> int.to_string(value)
}

fn string_field(name: String, value: String) -> String {
  "\"" <> name <> "\":\"" <> escape_json(value) <> "\""
}

/// Escape `input` for use inside a JSON string, without the surrounding
/// quotes. Non-ASCII is passed through, which JSON allows.
pub fn escape_json(input: String) -> String {
  input
  |> string.to_utf_codepoints()
  |> escape_codepoints("")
}

fn escape_codepoints(codepoints: List(UtfCodepoint), acc: String) -> String {
  case codepoints {
    [] -> acc
    [codepoint, ..rest] -> escape_codepoints(rest, acc <> escape_one(codepoint))
  }
}

fn escape_one(utf: UtfCodepoint) -> String {
  let codepoint = string.utf_codepoint_to_int(utf)
  case codepoint {
    0x22 -> "\\\""
    0x5C -> "\\\\"
    0x08 -> "\\b"
    0x0C -> "\\f"
    0x0A -> "\\n"
    0x0D -> "\\r"
    0x09 -> "\\t"
    _ ->
      case codepoint < 0x20 {
        True -> "\\u" <> hex(codepoint)
        False -> [utf] |> string.from_utf_codepoints()
      }
  }
}

/// Lowercase hex, at least four digits, so a control character never appears
/// as `\u{1f}`. `int.to_base_string` cannot fail for a value below 0x20; the
/// empty fallback just keeps the function total.
fn hex(codepoint: Int) -> String {
  // `int.to_base_string` is uppercase; JSON does not care, but a stable shape
  // makes the output diffable.
  let digits = case int.to_base_string(codepoint, 16) {
    Ok(digits) -> string.lowercase(digits)
    Error(Nil) -> ""
  }
  case string.length(digits) >= 4 {
    True -> digits
    False -> "0000" |> string.slice(0, 4 - string.length(digits)) <> digits
  }
}
