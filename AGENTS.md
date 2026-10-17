# AGENTS.md

Rust project. All tooling runs in Docker via Task; Rust on the host is not used.

## Commands

- `task check`: formats the code, then runs Clippy (warnings are errors) and tests. Run it after every change; work is done only when it passes.
- `task cargo -- <args>`: any other cargo command, e.g. `task cargo -- tree`.
- Don't run `task dev` (never exits) or a bare `task` (interactive menu); use `task run` to run the app once.
- Never run `cargo` or `rustc` directly: the host toolchain may differ from the one pinned in `rust-toolchain.toml`.

## Layout

- `src/lib.rs` holds the logic; `src/main.rs` stays a thin entry point.
- One module per concern; split a file before it grows past ~300 lines.
- Unit tests in a `#[cfg(test)] mod tests` next to the code; integration tests in `tests/`.
- When a module grows into its own subsystem, propose splitting it into a workspace crate under `crates/`.
- Architecture decisions live in `docs/decisions/`; read the relevant one before changing that area, and add one for each new decision.

## Rules

- For new behavior, write a failing test first, then the implementation.
- Model domain values as types (e.g. `struct UserId(u64)`) so the compiler catches misuse.
- Ask before adding a dependency; prefer std. Add with `task cargo -- add <crate>`.
- Servers listen on `0.0.0.0` (they run in a container) and shut down gracefully on SIGTERM.
- Prefer pure-Rust crates (e.g. rustls over OpenSSL): the production image has no system libraries besides glibc.
- Propagate errors with `?`; don't panic in library code.
- Errors: std's `Box<dyn Error + Send + Sync>` until the project needs more; then `anyhow` in the application layer (`main`, `run`) and `thiserror` enums for domain errors.
- Keep changes focused; don't refactor unrelated code.
- Don't change `rust-toolchain.toml` unless asked.
