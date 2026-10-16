# 001: Agentic Development Setup

This skeleton is set up so an agent works efficiently (few tokens) and the codebase stays manageable as it grows. This rationale lives in a decision record rather than in `AGENTS.md`, because everything in `AGENTS.md` is loaded into every agent session, and rather than in the README, because a project's README gets rewritten.

## 1. A Lean `AGENTS.md`
`AGENTS.md` is the cross-tool standard for agent instructions; `CLAUDE.md` only imports it. It contains just what an agent cannot derive from the code: which commands to use, the layout and the house rules. Every line costs tokens in every session, so keep it short and never explain Rust itself.

## 2. One Quiet Feedback Loop
`task check` is the single "am I done?" command for agents. It formats the code instead of only checking it, so an agent never spends a round trip on formatting (CI still rejects unformatted code). It runs in one container with quiet output, so a passing run costs a handful of lines while compiler errors stay complete (Rust's detailed errors are exactly what lets an agent fix its own mistakes).

## 3. Structure That Fits Agents
* **Guardrails as lints, not prose:** `unwrap()`/`expect()` outside tests and `#[allow]` without a reason fail the build (`Cargo.toml`, `clippy.toml`). The compiler enforces them every time, at zero token cost.
* **Logic in `lib.rs`, thin `main.rs`:** the logic stays testable and the entry point stays trivial.
* **Small modules:** an agent reading one 200-line file is far cheaper than reading one 2,000-line file.
* **Workspace when it grows:** split subsystems into crates under `crates/` so a task only requires understanding one crate. Don't start with a workspace; it is bloat for a small project.
* **Types as contracts:** domain types like `UserId` make the compiler catch an agent's mistakes before you review them.

## 4. Manageability
* **Shared permissions:** `.claude/settings.json` pre-approves `task` and read-only git commands, asks before `task cargo -- add`, and blocks direct `cargo`/`rustc` (pinned toolchain) and `task dev` (never exits). Personal overrides go in `.claude/settings.local.json` (git-ignored).
* **Tests as specification:** have the agent write a failing test first. You review the test, which is shorter than the implementation.
* **Small tasks, short sessions:** one feature per session, commit, then `/clear`. Long sessions accumulate context, cost more and get sloppier.
* **Decision records:** record each architecture decision as a short, numbered file in `docs/decisions/`, like this one. Agents only read them when relevant instead of in every session.
