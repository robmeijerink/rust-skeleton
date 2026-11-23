#!/bin/sh
# `task` inside the agent sandbox, which has no Docker: runs the same commands as the tasks in
# Taskfile.yaml, so AGENTS.md and .claude/settings.json hold in both places. Keep it in sync with
# Taskfile.yaml. Mounted read-only at /usr/local/bin/task (see docker-compose.yml).
set -e
cmd="$1"
if [ $# -gt 0 ]; then shift; fi
if [ "$1" = "--" ]; then shift; fi
case "$cmd" in
  check) cargo fmt --all && cargo clippy -q --locked --all-targets -- -D warnings && cargo test -q --locked ;;
  cargo) exec cargo "$@" ;;
  run) exec cargo run -- "$@" ;;
  test) exec cargo test ;;
  fmt) exec cargo fmt --all ;;
  *) echo "task '$cmd' is not available in the agent sandbox (available: check, cargo, run, test, fmt)" >&2; exit 1 ;;
esac
