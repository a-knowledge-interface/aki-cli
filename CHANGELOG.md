# Changelog

All notable changes to the released `aki` binary are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions
before 0.8.22 were internal; the history starts where the public releases do.

## [0.8.23] — 2026-09-04

### Changed

- Releases are now cut by CI: a version tag on the source repo builds, packages, tests
  and publishes here automatically, with the `/releases/latest/download/` contract
  verified from the outside on every cut.
- No changes to the binary's behavior since 0.8.22.

## [0.8.22] — 2026-09-04

First public release. Everything below is what ships in this binary.

### What aki is

`aki` hands a coding task to an AI agent that works across every repository in your
workspace at once. Each task gets its own git worktree and branch in every repo, so the
agent's work never touches your checkout and several tasks run in parallel. A task is one
session whether you drive it from the terminal or the browser — and you can hand it back
and forth mid-conversation.

### Tasks & isolation

- Multi-repo tasks: one branch name (`aki/<task>`) cut across every repo in the project,
  each checked out into its own worktree under `<project>/.aki/worktrees/`.
- `aki -p "<prompt>"` creates a task from a prompt and starts the agent on it;
  `aki t new` scaffolds one first (`--repos`, `--base`, `--agent`, `--notes`,
  `--template`).
- `aki t add-repo <task> <repo>` gives a running task one more of the project's repos,
  mid-flight — the worktree appears on the task's existing branch. Idempotent; re-adding
  repairs a lost checkout.
- `aki stop` checkpoints: uncommitted work is committed onto the task's own branch before
  the agent pauses, so nothing is stranded (`checkpoint_on_stop`, on by default).

### Lifecycle

- `aki diff` reviews the change across all of a task's repos at once (`--stat` for the
  short form).
- `aki merge` lands the task's branches and leaves the task open; `aki done` lands them
  and closes it; `aki clean` tears down worktrees and branches.
- The teardown protects you: `clean` refuses to delete an unmerged branch or a dirty
  worktree unless forced.
- `aki summary` writes a task's summary document; `aki t hist` shows completed history.

### Terminal & web, one session

- `aki start` / `aki go` drive a task in the terminal (via zellij); `aki web` hands the
  same session to the browser at visor.aki.am; `aki go` takes it back — full history
  intact.
- Nothing listens on a public port: a local daemon holds the session and dials out over a
  single WebSocket.
- In the browser: chat with the agent, approve or deny each tool call, watch its
  thinking, review the diff, commit and merge.
- Per-task **autonomy**: `manual` approves everything, `auto` approves tools but still
  asks real questions, `zevs` never pauses.

### Orchestration — tasks that run tasks

- `aki t wait <task> --until awaiting-input|idle|waiting|done|stopped [--timeout N]`
  blocks until a task reaches a state and answers with an exit code a script can act on
  (`0` reached, `2` timed out, `3` unreachable).
- `aki t send <task> "<text>"` hands a task's agent its next prompt — the supported way
  one agent drives another.
- The `on_agent_idle` hook fires once per transition when a browser-driven agent finishes
  a turn or blocks on a question, with `$AKI_AGENT_STATE` saying which.

### Project knowledge

- Every session is captured and indexed per project; `aki search` answers from past
  sessions and curated docs together.
- `aki doc create | list | show | edit | attach` manages project documents;
  `aki analyze` writes an AI architecture analysis of the workspace to `.aki/docs/`.
- `aki distill` turns a finished session into reviewable learnings
  (`aki learn list | promote | reject`); `aki index` rebuilds the search index.

### Install & distribution

- One self-contained binary — no Rust toolchain, no Node runtime. `install.sh` downloads
  the release for your platform, verifies its checksum, installs to `~/.local/bin`, and
  copies aki's Claude Code skills into `~/.claude/skills`.
- Installs are pinnable (`AKI_VERSION`) and relocatable (`AKI_INSTALL_DIR`,
  `AKI_SKILLS_DIR`, `AKI_NO_SKILLS=1`).
- Upgrades are atomic: the binary is replaced by rename, so a running daemon keeps its
  old build until it restarts.
- Release binaries carry no build-machine paths, and every asset ships with a `.sha256`
  published next to it.
- Platforms: `linux-x64`. (`linux-arm64`, `macos-arm64`, `macos-x64` are recognized by
  the installer but not yet built.) Linux binaries link system OpenSSL.

[0.8.23]: https://github.com/a-knowlage-interface/aki-cli/releases/tag/v0.8.23
[0.8.22]: https://github.com/a-knowlage-interface/aki-cli/releases/tag/v0.8.22
