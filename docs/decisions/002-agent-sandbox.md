# 002: Agent Sandbox

`task agent` runs Claude Code in a container, so an agent (even in auto-approve mode) can only reach this project and not the rest of the machine.

## What the Sandbox Guarantees
* **Only the project is mounted.** No home directory, no Docker socket, no host `~/.claude`.
* **Secrets in `.secrets/` stay out (opt-in).** `/app/.secrets` is an empty, read-only `tmpfs` in the sandbox, so the agent can't read what you keep there. Anything else in the project is readable, including a `.env` in the project root: the sandbox does not guess which files are secret. See [Secrets](#secrets).
* **The agent can't plant files that the host runs or reads.** `.git`, `Taskfile.yaml`, `Taskfile.local.yml`, `.devcontainer/` and `.claude/` are mounted read-only. Otherwise a git hook, a task, a compose change or a Claude Code hook could take effect outside the sandbox, on the host. A side effect is that the agent can't commit; `git status`, `git diff` and `git log` still work. You review and commit yourself.
* **Own volumes** (`agent_cargo`, `agent_rustup`, `agent_target`, `agent_claude`), not the `rust_*` ones the app uses. The agent can't plant a binary in a toolchain shared with other projects.
* **Hardened container:** non-root user (on Linux with your own uid, so it can write to the project), all capabilities dropped, `no-new-privileges`, a process limit.
* **No credentials for git remotes**, so the agent can't push.

## What It Does Not Guarantee
* **Code the agent writes runs outside the sandbox later.** `task check`, `task dev` and `task run` on the host run its `build.rs`, proc macros, tests and the app in the `app` container, which has none of the restrictions above: the whole project (including `.git` and the Taskfiles) and the shared `rust_*` volumes are writable, and `.env` files and `.secrets/` are readable. This is inherent: you want to run the code eventually. Review the diff (especially `build.rs`, new dependencies and tests) before running `task` on the host. An editor with rust-analyzer goes further: it runs build scripts and proc macros directly on the host as soon as you open a Rust file. That code can only come from a `build.rs` or a dependency, so before opening the project, check that this shows nothing unexpected (it includes new, untracked files):
  ```sh
  git status --short -- '*build.rs' '*Cargo.toml' Cargo.lock
  ```
* **The network is open.** The agent needs the Anthropic API, crates.io and the web. So what it can read can be sent out, for example after a prompt injection from a web page: the project's source code, its own login token and any personal skills or instructions you mounted. Secrets in `.secrets/` can't leak this way, but secrets elsewhere can: a `.env` that isn't symlinked into `.secrets/`, source code, other files, or the git history (`.git` is readable). The host and LAN are reachable too (e.g. `host.docker.internal`). Acceptable for a skeleton or open-source code; add an egress allowlist (proxy or firewall) when the project holds valuable or confidential code.
* **The agent shares the Compose network with the app and local infrastructure.** On purpose: it sees the same database and dev data as you, so its results match yours. Don't load production dumps with customer data into the dev database.
* **Other host-executed files** that this record doesn't list (for example `.mcp.json`, `.envrc`, editor config such as `.vscode/`, or `CLAUDE.local.md`) are writable. Check `git status --ignored` after an agent session, before running `claude`, `task` or your editor on the host: plain `git status` hides git-ignored files such as `.vscode/` and `CLAUDE.local.md`. They stay git-ignored on purpose, because they are personal and shouldn't be committed.

## Secrets
By default the agent can read every file in the project, including `.env`. To keep secrets out of its reach, store them in `.secrets/` and symlink the file the app expects:

```sh
mkdir -p .secrets && mv .env .secrets/.env && ln -s .secrets/.env .env
```

* **In the sandbox** the symlink dangles: the agent can't read the target, and `dotenv` (Node) and `phpdotenv` (Laravel) just find no file.
* **Everywhere else** (host, editor, the `app` container) the symlink resolves, so tools find `.env` in the project root as usual. Use a relative symlink: the project lives at `/app` in the containers.
* **Only test or dev keys locally.** Keys that cost money when abused (AI APIs, cloud accounts) go in `.secrets/`.
* **Secrets end up in other files.** Whatever the app writes into the project is readable: cache and build output (e.g. Laravel's `config:cache` writes every config value in plain text to `bootstrap/cache/config.php`; run `config:clear`), logs in the project (`storage/logs/`), and frontend bundles (`VITE_`/`NEXT_PUBLIC_` variables are inlined). Give money-costing keys a low spending limit, so a leak stays cheap.
* **Never in the production image:** `.secrets/` is in `.gitignore` and `.dockerignore`, like `.env`.
* **One symlink per file**: `.env.testing` and the like get their own. Anything secret outside `.env` (`auth.json`, `.npmrc` with a token, key files) belongs in `.secrets/` too.
* **Why not mask by filename?** An earlier version generated `/dev/null` mounts for `.env`-style files that existed at start. That only covers names we thought of and files that already exist, and it gave a false sense of safety. A directory that is always hidden has neither gap; the rule is "secrets go in `.secrets/`".
* **Give the agent fake values.** The sandbox needs config without real credentials. Set non-secret values in the `agent` service (`environment:` in `docker-compose.yml`, e.g. a dummy `APP_KEY` and an in-memory database): real environment variables take precedence over `.env` in Laravel and `dotenv`, and the agent can't change them (`.devcontainer/` is read-only). For tests, use the stack's own file with fake values (`.env.testing` in Laravel, `.env.test` in Vite) and commit it (add a `!` exception to `.gitignore`), next to a `.env.example`.
* **A warning, not a guarantee.** Once `.secrets/` contains files (the sandbox's mount creates the empty folder, so that alone doesn't count), `task agent` lists every `.env`, `.env.*` and `*.env` file that is a regular file instead of a symlink. It skips files tracked by git (a committed file is not a secret, e.g. `.env.example` or a `.env.testing` with fake values) and `target`, `node_modules`, `vendor` and `.git`. That catches a `.env` you forgot to move and a symlink the agent replaced. It does not look at other names, so no warning doesn't mean no readable secrets.
* **The symlink itself is writable.** The agent can replace it with a real `.env` of its own (your secrets stay intact), and the host would load that file. The warning above shows it at the next `task agent`; check with `readlink .env` before running the app on the host.
* **Create `.secrets/` yourself before the first `task agent`.** Docker creates the mountpoint if it is missing, on Linux possibly as root-owned (not tested there). Verified on macOS with Colima (virtiofs).

## Login
A Claude Pro/Max account has no API key. Log in once with `/login` in the sandbox; the token lives in the `agent_claude` volume. It never appears in the repo, compose file or Taskfile. A leaked token can use up your usage limits; with extra usage turned off, it can't cost you money. Revoke it by logging out in your account settings.

## Personal Skills and Instructions
The repo only knows two generic, empty-by-default volumes: `ai-skills-provider` (mounted at `~/.claude/skills`) and `ai-instructions-provider` (at `/opt/ai-instructions`), both read-only. Each developer binds them on their own machine to a local folder (`docker volume create --driver local --opt type=none --opt o=bind --opt device=<folder> <name>`), for example a folder in a notes vault. So no personal path, name or file ever ends up in the repo or an image, and the agent can't modify them. The agent can read them, though, and the network is open: mount a dedicated folder, not a whole vault.

## Versions
The image is deliberately unpinned (latest Claude Code via the native installer; npm installs are deprecated): it is a dev tool, not part of the app. Its auto-updater is off, because an update inside the container would be lost when the container is recreated. Docker caches the layers, so run `task agent:update` to get the latest version. Your login survives.

## `task` Inside the Sandbox
The sandbox has no Docker, so `.devcontainer/agent-task.sh` is mounted read-only as `task`: it runs the same cargo commands as `task check`, `run`, `test`, `fmt` and `cargo`. That keeps `AGENTS.md` and `.claude/settings.json` (which blocks direct `cargo`) valid in both places. Keep it in sync with `Taskfile.yaml`; a change takes effect without a rebuild.

## Other Stacks
`Dockerfile.dev-agent` is stack-agnostic. To give a Go, TypeScript, Python or Laravel project the same sandbox, copy unchanged:
* `Dockerfile.dev-agent`,
* the `agent`, `agent:prepare` and `agent:update` tasks and the `AGENT_UID` variable in `Taskfile.yaml`,
* the `agent` service in `docker-compose.yml` with its volumes (`agent_*`, `ai-skills-provider`, `ai-instructions-provider`),
* the `.secrets/` lines in `.gitignore` and `.dockerignore`,
* this record.

Then change only:
* the build args of the `agent` service: `BASE_IMAGE` (a Debian-based image, e.g. `golang:1-trixie`, `node:22-trixie`, `python:3-trixie` or `php:8.4-cli-trixie`; Alpine lacks `useradd` and `apt-get`) and `OWNED_DIRS` (toolchain and build directories that get their own volumes, e.g. `/go` for Go, `/app/node_modules`, `/app/.venv` or `/app/vendor`),
* the `agent_*` volumes for those directories,
* `.devcontainer/agent-task.sh`, to match that project's `Taskfile.yaml`, and the matching `deny` rules in `.claude/settings.json` (e.g. `npm`, `go` or `pip` instead of `cargo`),
* if the project needs more than the official image (Composer and PHP extensions such as `pdo_pgsql`), point `BASE_IMAGE` at the project's own dev image, so the agent has the same toolchain as the `app` service,
* the stack-specific examples in this record (e.g. `build.rs` becomes `postinstall`, Composer scripts or `conftest.py`).
