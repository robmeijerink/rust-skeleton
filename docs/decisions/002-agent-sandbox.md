# 002: Agent Sandbox

`task agent` runs Claude Code in a container, so an agent (even in auto-approve mode) can only reach this project and not the rest of the machine.

## What the Sandbox Guarantees
* **Only the project is mounted.** No home directory, no Docker socket, no host `~/.claude`.
* **Secrets in `.secrets/` stay out (opt-in).** It is an empty, read-only `tmpfs` in the sandbox. Everything else is readable, including a `.env` in the project root. See [Secrets](#secrets).
* **The agent can't plant files that the host runs.** `.git`, `Taskfile.yaml`, `Taskfile.local.yml`, `.devcontainer/` and `.claude/` are read-only, so no git hook, task, compose change or Claude Code hook can take effect on the host. As a side effect the agent can't commit; `git status`, `git diff` and `git log` still work. You review and commit yourself.
* **Own volumes** (`agent_cargo`, `agent_rustup`, `agent_target`, `agent_claude`), not the `rust_*` ones the app uses, so the agent can't plant a binary in a toolchain shared with other projects.
* **Hardened container:** non-root user (on Linux with your own uid, so it can write to the project), all capabilities dropped, `no-new-privileges`, a process limit.
* **No credentials for git remotes**, so the agent can't push.

## What It Does Not Guarantee
* **Code the agent writes runs outside the sandbox later.** `task check`, `task dev` and `task run` run its `build.rs`, proc macros, tests and the app in the `app` container, which has none of the restrictions above: the project and the shared `rust_*` volumes are writable, `.env` files and `.secrets/` are readable. This is inherent: you want to run the code eventually. Review the diff (especially `build.rs`, new dependencies and tests) before running `task` on the host.
* **Some project files run directly on the host, outside any container.** After an agent session, review the diff and `git status --ignored` before you open the project in an editor, run `claude` or commit (plain `git status` hides ignored personal files such as `.vscode/` and `CLAUDE.local.md`). The main cases:
  * **Editors.** rust-analyzer runs build scripts and proc macros, what `.cargo/config.toml` points to (e.g. a `rustc-wrapper`) and the toolchain `rust-toolchain.toml` selects, as soon as you open a Rust file. Quick check (it includes new, untracked files):
    ```sh
    git status --short -- '*build.rs' '*Cargo.toml' Cargo.lock '*.cargo/*' rust-toolchain.toml
    ```
    Other stacks' editors do the same with ESLint and Prettier configs, `conftest.py` or PHPStan's autoloader.
  * **Git hook managers.** Husky (`.husky/`), Lefthook (`lefthook.yml`, `lefthook-local.yml`) and pre-commit (`.pre-commit-config.yaml`) keep what a hook runs in project files, bypassing the read-only `.git`; git runs them at your next commit. This project uses none. If one is added, mount its files read-only in the `agent` service (e.g. `- ../.husky:/app/.husky:ro`), but only files that exist: Docker creates a missing source as an empty directory.
  * **Shell and agents on the host.** `.envrc` and `mise.toml` run on `cd`. `.mcp.json`, `AGENTS.md`, `CLAUDE.md` and `CLAUDE.local.md` instruct an agent you run on the host.
* **The network is open.** The agent needs the Anthropic API, crates.io and the web, so what it can read can be sent out, for example after a prompt injection from a web page: source code, the git history, its own login token, mounted skills and instructions, and secrets outside `.secrets/`. The host and LAN are reachable too (e.g. `host.docker.internal`). Acceptable for a skeleton or open-source code; add an egress allowlist (proxy or firewall) when the project holds valuable or confidential code.
* **The agent shares the Compose network with the app and local infrastructure.** On purpose: it sees the same database and dev data as you, so its results match yours. Don't load production dumps with customer data into the dev database.

## Secrets
By default the agent can read every file in the project, including `.env`. To keep secrets out of its reach, store them in `.secrets/` and symlink the file the app expects. Use a relative symlink, because the project lives at `/app` in the containers:

```sh
mkdir -p .secrets && mv .env .secrets/.env && ln -s .secrets/.env .env
```

In the sandbox the symlink dangles, and `dotenv` (Node) and `phpdotenv` (Laravel) just find no file. Everywhere else (host, editor, `app` container) it resolves as usual. Verified on macOS with Colima. Create `.secrets/` yourself before the first `task agent`: Docker creates a missing mountpoint, on Linux possibly root-owned (not tested there).

* **What goes in.** Anything secret: one symlink per file (`.env`, `.env.testing`, `auth.json`, `.npmrc` with a token, key files). Use only test or dev keys locally, and give keys that cost money when abused (AI APIs, cloud accounts) a low spending limit, so a leak stays cheap.
* **Fake values for the agent.** Set non-secret config in the `agent` service (`environment:`, e.g. a dummy `APP_KEY`): real environment variables take precedence over `.env`, and the agent can't change them. For tests, commit the stack's own file with fake values (`.env.testing`, `.env.test`) with a `!` exception in `.gitignore`.
* **Secrets leak into files the app writes.** Cache (Laravel's `config:cache` writes every value in plain text to `bootstrap/cache/config.php`; run `config:clear`), logs in the project (`storage/logs/`) and frontend bundles (`VITE_` and `NEXT_PUBLIC_` variables are inlined) are readable.
* **The symlink itself is writable.** The agent can replace it with a `.env` of its own (yours stays intact), which the host would then load. Once `.secrets/` has files, `task agent` warns about every `.env`, `.env.*` and `*.env` that is a regular file and not tracked by git. A hint, not a guarantee: it doesn't look at other names.
* **Why a directory instead of masks by filename?** Masks only cover the names you thought of and the files that exist at start. `.secrets/` is in `.gitignore` and `.dockerignore`, so it never reaches git or the production image.

## Login
A Claude Pro/Max account has no API key. Log in once with `/login` in the sandbox; the token lives in the `agent_claude` volume. It never appears in the repo, compose file or Taskfile. A leaked token can use up your usage limits; with extra usage turned off, it can't cost you money. Revoke it by logging out in your account settings.

## Personal Skills and Instructions
The repo only knows two generic, empty-by-default volumes: `ai-skills-provider` (mounted at `~/.claude/skills`) and `ai-instructions-provider` (at `/opt/ai-instructions`), both read-only. Each developer binds them on their own machine to a local folder (`docker volume create --driver local --opt type=none --opt o=bind --opt device=<folder> <name>`), for example a folder in a notes vault. So no personal path, name or file ever ends up in the repo or an image, and the agent can't modify them. The agent can read them, though, and the network is open: mount a dedicated folder, not a whole vault.

## Versions
The image is deliberately unpinned (latest Claude Code via the native installer; npm installs are deprecated): it is a dev tool, not part of the app. Its auto-updater is off, because an update inside the container would be lost when the container is recreated. Docker caches the layers, so run `task agent:update` to get the latest version. Your login survives.

## `task` Inside the Sandbox
The sandbox has no Docker, so `.devcontainer/agent-task.sh` is mounted read-only as `task`: it runs the same cargo commands as `task check`, `run`, `test`, `fmt` and `cargo`. That keeps `AGENTS.md` and `.claude/settings.json` (which blocks direct `cargo`) valid in both places. Keep it in sync with `Taskfile.yaml`; a change takes effect without a rebuild.

## Other Stacks
`Dockerfile.dev-agent` is stack-agnostic: tested with the Debian-based `rust`, `golang`, `node`, `python` and `php` `-trixie` images (Alpine lacks `useradd` and `apt-get`). To reuse the sandbox, copy unchanged: `Dockerfile.dev-agent`, the `agent` tasks and `AGENT_UID` in `Taskfile.yaml`, the `agent` service and its volumes in `docker-compose.yml`, the `.secrets/` lines in `.gitignore` and `.dockerignore`, and this record. Then change:
* `BASE_IMAGE`, and `OWNED_DIRS` with an `agent_*` volume per directory (toolchain and build output, e.g. `/go`, `/app/node_modules`, `/app/.venv` or `/app/vendor`). If the official image isn't enough (Composer, PHP extensions), use the project's own dev image, so the agent has the same toolchain as `app`.
* `.devcontainer/agent-task.sh` and the `deny` rules in `.claude/settings.json` (e.g. `npm`, `go` or `pip` instead of `cargo`).
* Read-only mounts for a git hook manager, if the project uses one.
* The stack-specific examples in this record (e.g. `build.rs` becomes `postinstall`, Composer scripts or `conftest.py`).
