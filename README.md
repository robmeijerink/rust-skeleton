# Rust Skeleton

A minimalist, container-first boilerplate for starting new Rust projects. All Rust operations run in Docker, so you don't need Rust installed locally, and the exact Rust version is pinned so the project still builds the same way years from now.

## Features

* **Zero Local Rust Dependency:** All build, test and run commands execute inside `rust:1-trixie` Docker containers.
* **Pinned Toolchain:** `rust-toolchain.toml` is the single source of truth for the Rust version in Docker, CI and (optionally) your local machine.
* **Taskfile Automation:** Simplified command execution with an interactive UI (replaces Makefiles).
* **Hot Reloading:** `task dev` uses [watchexec](https://github.com/watchexec/watchexec) to restart the app on every change.
* **Strict by Default:** Rust 2024 edition, `unsafe` forbidden, Clippy pedantic lints, and CI fails on any warning.
* **Production Docker Image:** A multi-stage build with cached dependencies, shipped on a distroless, non-root runtime image.
* **Clean Architecture:** Infrastructure config is neatly tucked away in the `.devcontainer/` directory (also enables one-click Dev Containers with `rust-analyzer`).

## Prerequisites

| Tool | Requirement |
| :--- | :--- |
| [Docker](https://docs.docker.com/get-docker/) & Docker Compose | Required |
| [Task](https://taskfile.dev/installation/) | Required |
| [fzf](https://github.com/junegunn/fzf) | Optional (Required for the interactive Task menu) |

*Note: A local Rust installation is strictly optional. If you have [rustup](https://rustup.rs/), it picks up the same pinned version automatically.*

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

Then update `.github/CODEOWNERS` and this README.

## Available Commands

This template uses `Taskfile.yaml` to manage standard development operations.

Run `task` without any arguments to open the interactive `fzf` search menu, or run specific tasks directly:

| Command               | Description |
| :---                  | :--- |
| <code>task&nbsp;init&nbsp;&#8209;&#8209;&nbsp;&lt;name&gt;</code> | Renames the project from `rust-skeleton` to `<name>`. |
| `task dev`            | Starts the app via Docker Compose and restarts it on every file change. |
| `task run`            | Runs the app once (pass arguments with `task run -- <args>`). |
| `task test`           | Executes the test suite. |
| `task check`          | Runs every CI check: formatting, Clippy and tests. |
| `task fmt`            | Formats the code. |
| <code>task&nbsp;cargo&nbsp;&#8209;&#8209;&nbsp;&lt;cmd&gt;</code> | Runs any cargo command (e.g., `task cargo -- add serde --features derive`). |
| `task build`          | Builds the production Docker image, tagged with the directory name. |
| `task clean`          | Removes build artifacts and shuts down containers. |

Add machine-specific tasks to a `Taskfile.local.yml`; it is included automatically if it exists.

## Upgrading Rust

Change `channel` in `rust-toolchain.toml` (e.g., to the latest stable), then run `task check`. Docker, CI and rustup all follow automatically.

## Project Structure

| File / Directory      | Description |
| :---                  | :--- |
| `src/main.rs`         | The application entry point. |
| `Cargo.toml`          | Package manifest, lint configuration and release profile. |
| `rust-toolchain.toml` | Pins the exact Rust version and components. |
| `Dockerfile`          | Multi-stage production image (distroless runtime). |
| `.devcontainer/`      | Dev Container config (`devcontainer.json`) and `docker-compose.yml` for local infrastructure. |
| `.github/`            | CI workflow, Dependabot config and `CODEOWNERS`. |
| `Taskfile.yaml`       | Task runner configuration. |

---

This repository serves as the official starting point for projects developed by [Solvalutions](https://solvalutions.com) and [Rob Meijerink](https://robmeijerink.nl).

*&copy;&nbsp;2026 &mdash; Built by Rob Meijerink to accelerate Rust development.*
