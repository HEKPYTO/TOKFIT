import fixtures/corpus
import gleam/list

/// One input and the token count real tiktoken gives it.
pub type Case {
  Case(text: String, tokens: Int)
}

pub fn cases() -> List(Case) {
  list.map(corpus.cases, fn(entry) {
    case entry {
      corpus.CorpusCase(text: text, tokens: tokens) ->
        Case(text: text, tokens: tokens)
    }
  })
}
