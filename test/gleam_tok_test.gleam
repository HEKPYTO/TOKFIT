import gleam_tok
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn package_module_is_importable_test() {
  let assert [] = gleam_tok.encode("")
}
