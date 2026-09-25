# AGENTS.md

## Engineering principles

- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.

## Scope Guard

Complete the task with the smallest sufficient change.
Explicit user instructions for this task override the defaults below.

### Before editing

- Read relevant code, call paths, and project conventions. Do not explore
  the entire repository before a small change.
- Make clear, small fixes directly. Write a short plan when the approach is
  unclear or the impact is substantial.
- Decide routine details yourself. Ask when different interpretations
  would lead to materially different work.
- Load only relevant Skills, not an entire workflow for a matching keyword.

### While editing

- Before adding code, check in this order:
  1. Existing code and patterns in the project
  2. Standard library and built-in platform capabilities
  3. Dependencies already installed
  4. Only then, new code required for the current task
- Fix the root cause. Do not add abstractions, configuration, or
  compatibility layers for hypothetical future needs.
- Justify new dependencies or frameworks: why are existing options not enough?
- Fix nearby issues only if they block the task. Otherwise, flag them
  for follow-up.
- Prefer precise edits for small changes. Avoid unrelated refactoring
  or whole-file rewrites.
- Remove replaced implementations. Keep old paths only when compatibility
  is explicitly required.
- Preserve necessary validation, error handling, security, and accessibility.

### When to ask

- Keep implementing, verifying, and fixing within the authorized scope.
  Do not repeatedly ask whether to continue.
- Confirm material scope expansion, unapproved costs or permissions,
  and unauthorized irreversible actions before proceeding.
- If asked only to analyze or review, report findings. Do not edit code.

### Testing

- Verify the change and its impact. Complete required project checks.
- Reuse existing tests first. Add tests for real behavior and regression
  risks, not tests that mechanically repeat the implementation.
- Temporary verification scripts need not become permanent test files.
- Once checks pass, broaden or repeat them only for new changes,
  failures, or specific unresolved concerns.

### If the plan grows

If you find future-only layers, unrelated refactoring, extra features,
or unjustified repeat checks, return to the current requirement.
Drop the excess work and finish within the existing authorization.

### Done means

- The requested behavior works and necessary verification is complete.
  Do not stop at a plan or an initial implementation.
- Every change serves the task. Remove obsolete code and temporary files
  introduced by this work.
- Briefly report the result, verification evidence, and anything
  unresolved or unverified.

## Workflow — Subagents as Workers, Main Chat as Advisor

- Main chat is advisor to all agents, not worker. It holds vision, decides, and reviews. It does not write code, run long builds, or hold heavy context.
- Subagents are workers. Every task that touches code, runs verification, or researches a domain is dispatched to a subagent via `Task` ( `subagent_type: general | explore | docs-manager` ) each subagents work in its own git worktree. Naming of that particular subagent must reflect on its goal to achieve and never use random generic naming.
- Worktree refers git worktree only, do not create working folder or placement (/tmp or other places).
- One task per subagent. No subagent handles two unrelated domains. Scope is a single file, corpus, or theory slice.
- Parallel by default. Independent domains run concurrently — see `docs/agents/workflow.md` for the DAG. No task blocks another; shared state is read-only (`origin/main`, `docs/plans/*`, `latest.json`).
- Use `skill://ponytail` ultra mode with all sub-skills, `skill://superpowers`, `skill://implement` or `skill://implement-spec`, `skill://sw-development-loops` and other skills or mcp tools or plugins in every worker.`  Each worker runs TDD red→green (one seam), autoresearch Classic `Metric: bug==0`, code-review (Standards/Spec parallel), audit delta, regression `STABLE` — all with `warnings as error`.
- Keep context lean. Workers read only what their task needs (`Read` + `Grep` + `Bash` with `timeout`). Main chat reads only summaries, not full diffs. Do not paste large files into main chat.

## Commits

- Concise commit messages, no extra commentary, messages less than 50 characters and in present tense.
- Use prefix, for example`feat/fix/docs/chore/refactor` follow by commit msg as `{prefix}: {commit msg}` while keeping history scannable and focusing on **what** and **why**, not how.
- Commit at phase/task completion or at crucial moments only. No small-change, experimental-design, or pre-breakage checkpoint commits.
- Attribute to the existing git user/email. Never invent contributor identities.

## Privacy — private repo

- Local-only by default: no `push`, no `--push`, no registry publish, no remote mention (URLs, image registries, remotes) unless the user explicitly asks in this conversation.
- Documented push/deploy commands are gated triggers for a future release step, not standing permission.
- No git init / remote add / network publish as a side effect of a build, scaffold, or verification step.
- No `*.md` files into commit tree except `README.md`
- On init project must have `.github/workflows` for CI/CD and `.github/dependabot.yml`. And must have precommit hooks (only lint and format. With NO test) for best practices

## Docs — README per subdirectory

- Code-adjacent docs live as `README.md` beside the code they describe (root, each `src/` module dir, `examples/`, `outputs/`). Update the affected `README.md` on every change that touches its directory.
- No new central docs folder or top-level markdown beyond per-dir `README.md` unless explicitly requested.
- Only `README.md`, `LICENSE`, and in advanced cases `CHANGELOG.md` may be committed as markdown files. No other `.md` files.
- Make sure that root `README.md` is concise and simple to read, attract users, and simple explanation of **what** and **how** to use this project. Other sub-driectories `README.md` require deep but concise documentation of each modules in details. Design the most appropriate method (table or alignment) to make sure that all `README.md` information is presented in best methodology for human as possible (maybe use writing-skills).
- Never mention generation tooling or provenance in docs or replies.

## Skill policy

- When skills are available, work in Poteto Mode (`skill://Poteto Mode`, trigger `/poteto-mode`) with `skill://using-superpowers` and `skill://ponytail`. Its non-negotiables apply to every multi-step task in this repo.
- Start each multi-step task with a todolist whose first item is reading the Poteto Mode Principles section in full. Name each principle that shaped a decision and the choice it changed.
- Follow matt-pocock skills, verify whether the repo accepts a GitHub issue/PR tracker (`gh` remote present). If none, still init matt-pocock antsetup without involving PR/issue tracker (including code-review skill step 2); spec source falls back to docs/ and its subdirectories.
- Apply the `unslop` skill to every prose surface, including replies.
- During any `plans and specs` design, make sure to create a deeply detailed `tasks, phases and steps` to complete user objective requests. Make sure that generated plan is truly "the best design and long-term production ready for this project ?", keep looping and aksing this question until it is truly perfected with high confidence.
- Route multi-step feature work through `skill://sw-development-loop` and `skill://implement` when available, with `skill:superpowers` and `skill://ponytail` applied throughout the loop.
- At the end of multi-step task (phase), if user specified any optimization target use `skill://autoresearch` or finding ideas using `skill://deep-research` as loops making sure coding is best at efficientcy and best standards as user specify.
- Apply the `unslop` skill to every prose surface, including replies.
- For frontend work, apply `skill://design-taste-frontend` and `skill://impeccable` for UX/UI designs when available, ALL UX/UI design must be responsive for all screen sizes.
- Spawn subagents as `poteto-agent` inside playbook steps. Match each task to a Poteto Mode playbook and copy its steps verbatim into the todolist before task-specific todos.

Prefer parallel subagents in different git worktree and merge back into main after each session / phase sprint finishes.
