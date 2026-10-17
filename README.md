# Rust Skeleton

A minimalist, container-first boilerplate for building Rust software with agentic AI (Claude Code, Codex, Cursor, ...). All Rust operations run in Docker, so you don't need Rust installed locally, and the exact Rust version is pinned so the project still builds the same way years from now.

## Features

* **Zero Local Rust Dependency:** All build, test and run commands execute inside `rust:1-trixie` Docker containers.
* **Pinned Toolchain:** `rust-toolchain.toml` is the single source of truth for the Rust version in Docker, CI and (optionally) your local machine.
* **Taskfile Automation:** Simplified command execution with an interactive UI (replaces Makefiles).
* **Hot Reloading:** `task dev` uses [watchexec](https://github.com/watchexec/watchexec) to restart the app on every change.
* **Agent-Ready:** A lean `AGENTS.md`, guardrails enforced by lints, a quiet single-command feedback loop and pre-approved agent permissions. See [Working with AI Agents](#working-with-ai-agents).
* **Strict by Default:** Rust 2024 edition, `unsafe` forbidden, Clippy pedantic lints, and CI fails on any warning.
* **Production Docker Image:** A multi-stage build with cached dependencies, shipped on a distroless, non-root runtime image.
* **Tidy Root:** Infrastructure config is neatly tucked away in the `.devcontainer/` directory (also enables one-click Dev Containers with `rust-analyzer`).

## Prerequisites

| Tool | Requirement |
| :--- | :--- |
| [Docker](https://docs.docker.com/get-docker/) with Compose and [Buildx](https://github.com/docker/buildx) | Required (Docker Desktop includes both; on Colima: `brew install docker-buildx`) |
| [Task](https://taskfile.dev/installation/) | Required |
| [fzf](https://github.com/junegunn/fzf) | Optional (Required for the interactive Task menu) |

*Note: A local Rust installation is strictly optional. If you have [rustup](https://rustup.rs/), it picks up the same pinned version automatically.*

* **First run:** the first command downloads the toolchain and the first `task dev` compiles watchexec; this takes a few minutes once, then everything is cached in Docker volumes.
* **Shared caches:** the toolchain and crate cache live in the Docker volumes `rust_cargo` and `rust_rustup`, shared by all projects (like a local `~/.cargo`). Reset them with `docker volume rm rust_cargo rust_rustup`; build output (`target/`) stays per project.
* **File sharing:** the project must be in a directory Docker can access (Docker Desktop: *Settings → Resources → File sharing*; Colima: `mounts` in `colima.yaml`, default `~`). Otherwise the container sees an empty `/app` and cargo reports a missing `Cargo.toml`.
* **Linux hosts:** files created inside the container (e.g. by `task fmt`) are owned by root.
* **Ports:** `task dev` publishes port 8080 on localhost only; change it per project in `.devcontainer/docker-compose.yml` to avoid clashes.
* **CPU architecture:** `task build` builds for your machine's architecture. For a server with another one, use `docker build --platform linux/amd64 .` (slow under emulation) or build in CI.

## Getting Started

### 1. Create a New Project
Click the **Use this template** button on GitHub to generate a new repository.

### 2. Clone the Repository

```bash
git clone git@github.com:your-org/your-new-project.git
cd your-new-project
```

### 3. Rename the Project
Replace the `rust-skeleton` placeholder with your crate name:

```bash
task init -- my-project
```

Then update `.github/CODEOWNERS` and this README (keep `docs/decisions/`).

### 4. Start Developing

```bash
task check   # verify everything works (first run takes a few minutes)
task dev     # run the app with hot reloading
```

## Available Commands

This template uses `Taskfile.yaml` to manage standard development operations.

Run `task` without any arguments to open the interactive `fzf` search menu, or run specific tasks directly:

| Command               | Description |
| :---                  | :--- |
| <code>task&nbsp;init&nbsp;&#8209;&#8209;&nbsp;&lt;name&gt;</code> | Renames the project from `rust-skeleton` to `<name>`. |
| `task dev`            | Starts the app via Docker Compose and restarts it on every file change. |
| `task run`            | Runs the app once (pass arguments with `task run -- <args>`). |
| `task test`           | Executes the test suite. |
| `task check`          | Formats the code, then runs Clippy and tests (CI checks the same, without formatting). |
| `task fmt`            | Formats the code. |
| <code>task&nbsp;cargo&nbsp;&#8209;&#8209;&nbsp;&lt;cmd&gt;</code> | Runs any cargo command (e.g., `task cargo -- add serde --features derive`). |
| `task build`          | Builds the production Docker image, tagged with the directory name. |
| `task clean`          | Removes build artifacts and shuts down containers. |

Add machine-specific tasks to a `Taskfile.local.yml`; it is included automatically if it exists.

## Working with AI Agents

The setup keeps agents efficient (few tokens) and the codebase manageable as it grows: a lean `AGENTS.md`, a quiet `task check` feedback loop, guardrails enforced by lints, and shared permissions. The full rationale, and how to keep it that way, is in [`docs/decisions/001-agentic-development-setup.md`](docs/decisions/001-agentic-development-setup.md). Keep that file when you rewrite this README.

## Upgrading Rust

Change `channel` in `rust-toolchain.toml` (e.g., to the latest stable), then run `task check`. Docker, CI and rustup all follow automatically.

Dependabot doesn't know the pinned version: if one of its PRs fails because a crate needs a newer Rust, upgrade Rust first. Upgrade deliberately but regularly; a gap of several years makes the jump harder.

## Project Structure

| File / Directory      | Description |
| :---                  | :--- |
| `src/lib.rs`          | The application logic. |
| `src/main.rs`         | The application entry point (calls `run` in `lib.rs`). |
| `AGENTS.md`           | Instructions for AI agents (`CLAUDE.md` imports it). |
| `docs/decisions/`     | Architecture decision records, starting with the agentic setup. |
| `.claude/`            | Shared Claude Code permissions (allow `task`, ask before adding crates, block direct `cargo`). |
| `clippy.toml`         | Allows `unwrap()`/`expect()` in tests only. |
| `Cargo.toml`          | Package manifest, lint configuration and release profile. |
| `rust-toolchain.toml` | Pins the exact Rust version and components. |
| `Dockerfile`          | Multi-stage production image (distroless runtime). |
| `.devcontainer/`      | Dev Container config (`devcontainer.json`) and `docker-compose.yml` for local infrastructure. |
| `.github/`            | CI workflow, Dependabot config and `CODEOWNERS`. |
| `Taskfile.yaml`       | Task runner configuration. |

---

This repository serves as the official starting point for projects developed by [Solvalutions](https://solvalutions.com) and [Rob Meijerink](https://robmeijerink.nl).

*&copy;&nbsp;2026 &mdash; Built by Rob Meijerink to accelerate agentic Rust development.*
