<!--
  SOURCE OF TRUTH: this file lives at public/CHANGELOG.md in the aki-cli source
  repo and is pushed here by the release workflow. Edit it there, never here: an
  edit made here is overwritten by the next release.

  This is the USER-FACING changelog, describing the released binary. The source
  repo keeps its own CHANGELOG.md with the engineering detail behind each change.
-->

# Changelog

All notable changes to the released `aki` binary are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions
before 0.8.22 were internal; the history starts where the public releases do.

## [0.8.30] — 2026-09-11

### Changed

- This repo's README, changelog and installer are now published from the source repo on
  every release, so they can no longer drift from the binary they describe.

## [0.8.29] — 2026-09-11

### Changed

- This repo's README is now published from the source repo on every release. It had gone
  two releases without mentioning agents, describing a product that no longer matched the
  binary beside it.
- Internal dependency upgrade that drops a crate a future Rust release will reject.
  `aki ls`, `aki pls` and `aki info` render exactly as before.

## [0.8.28] — 2026-09-11

### Added

- **Agents: named teammates that outlive a task.** A task's AI session ends with the task;
  an agent is the persistent kind, with a name, standing instructions, a model, an autonomy
  level, and one continuous conversation that carries from one assignment to the next.
  - `aki agent new` / `list` / `show` / `edit` / `rm` create and shape one. An edit reaches
    a *working* agent at its next pause rather than only at the next spawn, so a corrected
    brief lands without a restart. Retiring keeps the history, and re-creating the name
    restores it.
  - `aki agent ask` queues work and `--wait` blocks for the result, which makes an agent
    scriptable. `jobs` shows the queue and `cancel` drops one that has not started. Work is
    a queue, not a chat: an agent runs one job at a time, in order.
  - `aki agent schedule` gives an agent standing work. Alongside `--every 1h` and
    `--daily 09:00`, `--when` takes plain language ("every weekday at 09:00", "every monday
    at 10:00 yerevan time") and answers with a schedule aki can actually execute or refuses
    with a reason, never a near-miss. It echoes the canonical sentence and the exact cron
    line so you can see what it understood before trusting it.
  - An agent can drive a whole task: it briefs the task's session, lets the work happen in
    the task's own worktrees, then reviews the outcome before reporting back.

### Fixed

- A task job interrupted by a restart is reclaimed when the daemon comes back and resumes at
  review, instead of dispatching a second time. A deploy mid-task no longer wedges that
  agent's queue or briefs the work twice.
- A scheduled weekly job reported its missed runs against the wrong interval, so a
  Mondays-only schedule that missed three weeks claimed to have missed twenty-one.

## [0.8.26] — 2026-09-05

### Changed

- Release-pipeline housekeeping only; the binary is behaviorally identical to 0.8.24.

## [0.8.25] — 2026-09-05

### Changed

- The installer now warns when another `aki` earlier on your `PATH` shadows the one it
  just installed (a stale from-source build in `~/.cargo/bin` is the classic case), and
  prints the fix.
- Release-pipeline housekeeping; the binary is behaviorally identical to 0.8.24.

## [0.8.24] — 2026-09-05

### Added

- **macOS is a released platform**: `macos-arm64` and `macos-x64` assets ship with every
  release, built for macOS 11 (Big Sur) and newer. The installer already knew how to pick
  them; now they exist.

### Notes

- The curl installer is unaffected by Gatekeeper. A tarball downloaded in a browser is
  quarantined — `xattr -d com.apple.quarantine <file>` before extracting. Binaries are
  ad-hoc signed, not notarized.
- macOS binaries use the system Security framework for TLS — no extra packages, unlike
  the Linux OpenSSL note below.

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

[0.8.26]: https://github.com/a-knowledge-interface/aki-cli/releases/tag/v0.8.26
[0.8.25]: https://github.com/a-knowledge-interface/aki-cli/releases/tag/v0.8.25
[0.8.24]: https://github.com/a-knowledge-interface/aki-cli/releases/tag/v0.8.24
[0.8.23]: https://github.com/a-knowledge-interface/aki-cli/releases/tag/v0.8.23
[0.8.22]: https://github.com/a-knowledge-interface/aki-cli/releases/tag/v0.8.22
