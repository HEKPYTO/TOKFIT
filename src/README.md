# src

The package's public surface is `src/gleam_tok.gleam`. That file is the only
module a user needs to import.

| Module | Role |
|---|---|
| `gleam_tok` | `count`, `encode`, `trim_to_budget`. The public API. |
| `gleam_tok/cli` | The `count`, `trim`, and `encode` commands. Emits JSON. |
| `gleam_tok/bench` | Throughput measurement. |
| `gleam_tok/internal/*` | Not API. Hidden from generated docs by `internal_modules` in `gleam.toml`. |

See `gleam_tok/README.md` and `gleam_tok/internal/README.md` for detail.
