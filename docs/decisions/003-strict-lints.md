# 003: Strict Lints for Agents

Default Clippy is too lenient for agent-written code: agents reach for `unwrap()`, `panic!`, `todo!()` and `#[allow]` to get a build green. Lints enforce the rules in `AGENTS.md` at zero token cost.

## What's Enabled
* `clippy::pedantic`, plus targeted restriction lints in `Cargo.toml`: `panic`, `todo`, `unimplemented`, `dbg_macro`, `indexing_slicing`, `unwrap_used`, `expect_used`.
* `allow_attributes` and `allow_attributes_without_reason`: silencing a lint needs `#[expect(..., reason = "...")]`, which itself fails once the lint no longer fires, so suppressions can't go stale.
* `clippy.toml` relaxes unwrap, expect, panic, indexing and `dbg!` in tests only.
* `print_stdout` is deliberately off: the skeleton's `run` prints. Enable it once the app has real logging.

## Tiers
* **`task check`** stays fast (fmt, clippy, tests): it runs after every change.
* **Add later, when there is something to check:**
  * `cargo-deny` and `cargo-machete` in CI (advisories, licenses, unused dependencies) once the project has dependencies.
  * `cargo-mutants` in CI once the project has tests. It catches weak or deleted tests but is slow and needs a real test suite.

## Limits
* Lints run locally, so an agent can edit `Cargo.toml` or `clippy.toml`. The real enforcement is CI plus branch protection with required review (`CODEOWNERS` covers these files). Only the `.git`, Taskfiles, `.devcontainer/` and `.claude/` are read-only in the sandbox.
* Not a workspace yet, so lints live in `[lints]`. When splitting into `crates/`, move them to `[workspace.lints]` with `lints.workspace = true` per crate.
