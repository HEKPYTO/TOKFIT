import argv
import gleam/string
import gleam_tok/cli
import gleeunit

pub fn main() {
  gleeunit.main()
}

fn output(arguments: List(String)) -> String {
  case cli.try_run(arguments) {
    Ok(json) -> json
    Error(message) -> message
  }
}

/// Pins the `argv` shape the CLI's `main` depends on: `argv.load()` is a
/// record, not a `Result`, and both `runtime` and `program` are populated on
/// each target.
pub fn argv_load_is_a_populated_record_test() {
  let loaded = argv.load()
  let assert True = string.length(loaded.program) > 0
  let assert True = string.length(loaded.runtime) > 0
}

/// Its `arguments` is the command line with the program name already removed,
/// so the command is the first element. A program name in front of it is a
/// usage error, not something to skip over.
pub fn program_name_in_front_is_a_usage_error_test() {
  let assert True = string.contains(output(["gleam-tok", "count"]), "usage:")
  let assert True = string.contains(output(["count", "--text", "hi"]), "tokens")
}

pub fn count_emits_one_line_of_json_test() {
  let line = output(["count", "--text", "hello world"])
  let assert False = string.contains(line, "\n")
  let assert True = string.starts_with(line, "{\"encoding\":\"o200k_base\"")
  let assert True = string.contains(line, "\"tokens\":2")
}

pub fn count_emits_the_documented_line_test() {
  let assert Ok(
    "{\"encoding\":\"o200k_base\",\"tokens\":2,\"characters\":11,\"bytes\":11}",
  ) = cli.try_run(["count", "--text", "hello world"])
}

pub fn count_reports_characters_and_bytes_test() {
  let line = output(["count", "--text", "hello world"])
  let assert True = string.contains(line, "\"characters\":11")
  let assert True = string.contains(line, "\"bytes\":11")
}

pub fn count_uses_bytes_not_codepoints_for_multibyte_test() {
  let line = output(["count", "--text", "日本語"])
  let assert True = string.contains(line, "\"characters\":3")
  let assert True = string.contains(line, "\"bytes\":9")
}

pub fn trim_emits_budget_and_text_test() {
  let line = output(["trim", "--text", "hello world", "--budget", "1"])
  let assert True = string.contains(line, "\"budget\":1")
  let assert True = string.contains(line, "\"text\":\"hello\"")
  let assert True = string.contains(line, "\"dropped_pieces\":1")
}

pub fn trim_emits_the_documented_line_test() {
  let assert Ok(
    "{\"encoding\":\"o200k_base\",\"budget\":1,\"tokens\":1,\"characters\":5,\"dropped_pieces\":1,\"text\":\"hello\"}",
  ) = cli.try_run(["trim", "--text", "hello world", "--budget", "1"])
}

pub fn trim_with_a_generous_budget_keeps_everything_test() {
  let line = output(["trim", "--text", "hello world", "--budget", "100"])
  let assert True = string.contains(line, "\"text\":\"hello world\"")
  let assert True = string.contains(line, "\"tokens\":2")
}

pub fn encode_emits_a_token_array_test() {
  let line = output(["encode", "--text", "hello world"])
  let assert True =
    string.starts_with(line, "{\"encoding\":\"o200k_base\",\"tokens\":[")
  let assert True = string.ends_with(line, "]}")
}

pub fn unknown_command_is_a_usage_error_test() {
  let assert True = string.contains(output(["nope"]), "usage:")
}

pub fn missing_text_is_a_usage_error_test() {
  let assert True = string.contains(output(["count"]), "usage:")
}

pub fn bad_budget_is_a_usage_error_test() {
  let line = output(["trim", "--text", "hi", "--budget", "abc"])
  let assert True = string.contains(line, "usage:")
}

pub fn help_is_the_usage_string_test() {
  let assert True = string.contains(output(["--help"]), "usage:")
  let assert True = string.contains(output(["-h"]), "usage:")
}

pub fn json_escaping_covers_the_dangerous_characters_test() {
  let assert "\\\"" = cli.escape_json("\"")
  let assert "\\\\" = cli.escape_json("\\")
  let assert "\\n" = cli.escape_json("\n")
  let assert "\\r" = cli.escape_json("\r")
  let assert "\\t" = cli.escape_json("\t")
  let assert "\\b" = cli.escape_json("\u{8}")
  let assert "\\f" = cli.escape_json("\u{c}")
  let assert "\\u0001" = cli.escape_json("\u{1}")
  let assert "\\u001f" = cli.escape_json("\u{1f}")
  let assert "plain" = cli.escape_json("plain")
}

pub fn json_escaping_leaves_non_ascii_alone_test() {
  let assert "日本語" = cli.escape_json("日本語")
}

pub fn trim_escapes_control_characters_in_its_output_test() {
  let line = output(["trim", "--text", "a\u{1}b\u{2}c", "--budget", "100"])
  let assert True = string.contains(line, "\\u0001")
  let assert False = string.contains(line, "\u{1}")
}
