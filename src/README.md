# src

The package's public surface is `src/tokfit.gleam`. That file is the only
module a user needs to import.

| Module | Role |
|---|---|
| `tokfit` | `count`, `encode`, `trim_to_budget`, `encoding_name`, `Trimmed`. The public API. |
| `tokfit/cli` | The `count`, `trim`, and `encode` commands. Emits JSON. |
| `tokfit/bench` | Throughput measurement. |
| `tokfit/internal/*` | Not API. Hidden from generated docs by `internal_modules` in `gleam.toml`. |

See `tokfit/README.md` and `tokfit/internal/README.md` for detail.
