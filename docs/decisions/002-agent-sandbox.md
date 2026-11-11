# 002: Agent Sandbox

`task agent` runs Claude Code in a container, so an agent (even in auto-approve mode) can only reach this project and not the rest of the machine.

## What the Sandbox Guarantees
* **Only the project is mounted.** No home directory, no Docker socket, no host `~/.claude`.
* **Secrets stay out:** `task agent` masks every `.env`, `.env.*` and `*.env` file (also in subfolders, not `.env.example`) with `/dev/null`. It lists the files that exist at start, and only those, because mounting over a missing file would make Docker create an empty one in the project. A secret file created while the sandbox runs is masked after the next `task agent`. Other names (e.g. `secrets.json`) are not masked; keep secrets in `.env` files.
* **The agent can't plant files that the host runs or reads.** `.git`, `Taskfile.yaml`, `Taskfile.local.yml`, `.devcontainer/` and `.claude/` are mounted read-only. Otherwise a git hook, a task, a compose change or a Claude Code hook could take effect outside the sandbox, on the host. A side effect is that the agent can't commit; `git status`, `git diff` and `git log` still work. You review and commit yourself.
* **Own volumes** (`agent_cargo`, `agent_rustup`, `agent_target`, `agent_claude`), not the `rust_*` ones the app uses. The agent can't plant a binary in a toolchain shared with other projects.
* **Hardened container:** non-root user (on Linux with your own uid, so it can write to the project), all capabilities dropped, `no-new-privileges`, a process limit.
* **No credentials for git remotes**, so the agent can't push.

## What It Does Not Guarantee
* **Code the agent writes runs outside the sandbox later.** `task check`, `task dev` and `task run` on the host run its `build.rs`, proc macros, tests and the app in the `app` container, which has none of the restrictions above: the whole project (including `.git` and the Taskfiles) and the shared `rust_*` volumes are writable, and `.env` files are readable. This is inherent: you want to run the code eventually. Review the diff (especially `build.rs`, new dependencies and tests) before running `task` on the host. An editor with rust-analyzer goes further: it runs build scripts and proc macros directly on the host as soon as you open a Rust file. That code can only come from a `build.rs` or a dependency, so before opening the project, check that this shows nothing unexpected (it includes new, untracked files):
  ```sh
  git status --short -- '*build.rs' '*Cargo.toml' Cargo.lock
  ```
* **The network is open.** The agent needs the Anthropic API, crates.io and the web. So what it can read can be sent out, for example after a prompt injection from a web page: the project's source code, its own login token and any personal skills or instructions you mounted. Secrets in masked `.env` files can't leak this way, but secrets elsewhere can: in source code, in other files, or in the git history (`.git` is readable). The host and LAN are reachable too (e.g. `host.docker.internal`). Acceptable for a skeleton or open-source code; add an egress allowlist (proxy or firewall) when the project holds valuable or confidential code.
* **Other host-executed files** that this record doesn't list (for example `.mcp.json`, `.envrc`, editor config such as `.vscode/`, or `CLAUDE.local.md`) are writable. Check `git status --ignored` after an agent session, before running `claude`, `task` or your editor on the host: plain `git status` hides git-ignored files such as `.vscode/` and `CLAUDE.local.md`. They stay git-ignored on purpose, because they are personal and shouldn't be committed.

## Login
A Claude Pro/Max account has no API key. Log in once with `/login` in the sandbox; the token lives in the `agent_claude` volume. It never appears in the repo, compose file or Taskfile. A leaked token can use up your usage limits; with extra usage turned off, it can't cost you money. Revoke it by logging out in your account settings.

## Personal Skills and Instructions
The repo only knows two generic, empty-by-default volumes: `ai-skills-provider` (mounted at `~/.claude/skills`) and `ai-instructions-provider` (at `/opt/ai-instructions`), both read-only. Each developer binds them on their own machine to a local folder (`docker volume create --driver local --opt type=none --opt o=bind --opt device=<folder> <name>`), for example a folder in a notes vault. So no personal path, name or file ever ends up in the repo or an image, and the agent can't modify them. The agent can read them, though, and the network is open: mount a dedicated folder, not a whole vault.

## Versions
The image is deliberately unpinned (latest Claude Code via the native installer; npm installs are deprecated): it is a dev tool, not part of the app. Its auto-updater is off, because an update inside the container would be lost when the container is recreated. Docker caches the layers, so run `task agent:update` to get the latest version. Your login survives.

## `task` Inside the Sandbox
The sandbox has no Docker, so the image contains a small `task` script that runs the same cargo commands as `task check`, `run`, `test`, `fmt` and `cargo`. That keeps `AGENTS.md` and `.claude/settings.json` (which blocks direct `cargo`) valid in both places. Keep the script in `Dockerfile.dev-agent` in sync with `Taskfile.yaml`.
