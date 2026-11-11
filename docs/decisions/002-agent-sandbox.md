# 002: Agent Sandbox

`task agent` runs Claude Code in a container, so an agent (also in auto-approve mode) can only reach this project and not the rest of the machine.

## What the Sandbox Guarantees
* **Only the project is mounted.** No home directory, no Docker socket, no host `~/.claude`.
* **Secrets stay out:** `task agent` masks every `.env`, `.env.*` and `*.env` file (also in subfolders, not `.env.example`) with `/dev/null`. It lists the files that exist at start, and only those, because mounting over a missing file would make Docker create an empty one in the project. A secret file created while the sandbox runs is masked after the next `task agent`. Other names (e.g. `secrets.json`) are not masked; keep secrets in `.env` files.
* **Nothing the agent writes runs on the host.** `.git`, `Taskfile.yaml`, `Taskfile.local.yml`, `.devcontainer/` and `.claude/` are mounted read-only. Otherwise a git hook, a task, a compose change or a Claude Code hook could execute outside the sandbox, on the host. A side effect is that the agent can't commit; `git status`, `git diff` and `git log` work. You review and commit yourself.
* **Own volumes** (`agent_cargo`, `agent_rustup`, `agent_target`, `agent_claude`), not the `rust_*` ones the app uses. The agent can't plant a binary in a toolchain shared with other projects.
* **Hardened container:** non-root user, all capabilities dropped, `no-new-privileges`, a process limit.
* **No credentials for git remotes**, so the agent can't push.

## What It Does Not Guarantee
* **The network is open.** The agent needs the Anthropic API, crates.io and the web. So what it can read can be sent out, for example after a prompt injection from a web page: the project's source code, its own login token and any personal skills or instructions you mounted. Secrets in masked `.env` files can't leak this way, but secrets elsewhere can: in source code, in other files, or in the git history (`.git` is readable). The host and LAN are reachable too (e.g. `host.docker.internal`). Acceptable for a skeleton or open-source code; add an egress allowlist (proxy or firewall) when the project holds valuable or confidential code.
* **Other host-executed files** that this record doesn't list (for example a new `.mcp.json` or editor config) are writable. Check `git status` after an agent session, before running `claude` or `task` on the host.

## Login
A Claude Pro/Max account has no API key. Log in once with `/login` in the sandbox; the token lives in the `agent_claude` volume. It never appears in the repo, compose file or Taskfile. A leaked token can use up your usage limits but is not tied to a payment method (keep extra usage off). Revoke it by logging out in your account settings.

## Personal Skills and Instructions
The repo only knows two generic, empty-by-default volumes: `ai-skills-provider` (mounted at `~/.claude/skills`) and `ai-instructions-provider` (at `/opt/ai-instructions`), both read-only. Each developer binds them on their own machine to a local folder (`docker volume create --driver local --opt type=none --opt o=bind --opt device=<folder> <name>`), for example a folder in a notes vault. So no personal path, name or file ever ends up in the repo or an image, and the agent can't modify them. The agent can read them, though, and the network is open: mount a dedicated folder, not a whole vault.

## Versions
The image is deliberately unpinned (Node.js LTS, latest Claude Code): it is a dev tool, not part of the app, and an outdated Claude Code only produces update warnings. Docker caches the layers, so run `task agent:update` to get the latest versions. Your login survives.

## `task` Inside the Sandbox
The sandbox has no Docker, so the image contains a small `task` script that runs the same cargo commands as `task check`, `run`, `test`, `fmt` and `cargo`. That keeps `AGENTS.md` and `.claude/settings.json` (which blocks direct `cargo`) valid in both places. Keep the script in `Dockerfile.dev-agent` in sync with `Taskfile.yaml`.
