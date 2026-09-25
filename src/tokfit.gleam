//// Byte-level BPE token counting and budget trimming for OpenAI's
//// `o200k_base` encoding.
////
//// Pure Gleam on both the Erlang and JavaScript runtimes. No NIFs, no FFI,
//// no network access, and no filesystem access at run time.

/// Encode `text` into a list of `o200k_base` token ids.
pub fn encode(text: String) -> List(Int) {
  let _ = text
  []
}
