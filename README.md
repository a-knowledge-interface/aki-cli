# aki

**Put AI to work across all your repos at once.**

`aki` hands a coding task to an AI agent that works across every repository in your
workspace simultaneously. Each task gets its own git worktree and branch in each repo, so
the agent's work never touches your checkout and several tasks can run in parallel. Drive
a task from your terminal, from the browser, or both — it's the same session either way.

```bash
cd ~/workspace/my-project
aki init
aki -p "fix the auth bug in the login flow"
```

This repository distributes the **released `aki` binary**. It is a single self-contained
executable — no Rust toolchain, no Node runtime, no `node_modules`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/a-knowlage-interface/aki-cli/main/install.sh | bash
```

The installer downloads the binary for your platform from
[Releases](https://github.com/a-knowlage-interface/aki-cli/releases), verifies its
checksum, installs it to `~/.local/bin`, and copies aki's Claude Code skills into
`~/.claude/skills`.

To upgrade, run the same command again — the binary is replaced atomically by rename, so
a running `aki` daemon keeps its old build until it restarts.

| Variable | Default | |
|---|---|---|
| `AKI_VERSION` | latest release | pin a version, e.g. `0.8.22` |
| `AKI_INSTALL_DIR` | `~/.local/bin` | where the binary goes |
| `AKI_SKILLS_DIR` | `~/.claude/skills` | where the skills go |
| `AKI_NO_SKILLS` | — | set to `1` to skip skills |

Prefer to do it by hand? Download `aki-<platform>.tar.gz` from the release, verify it
against the published `.sha256`, and move `aki` onto your `PATH`.

### Platforms

| Platform | Status |
|---|---|
| `linux-x64` | published |
| `linux-arm64` | not yet built |
| `macos-arm64` | not yet built |
| `macos-x64` | not yet built |

The installer already knows all four; it will tell you clearly if a release has no asset
for your platform yet.

### Prerequisites

Not bundled — the installer checks for them and tells you what's missing:

- **git** — aki works through git worktrees
- **[Claude CLI](https://docs.anthropic.com/en/docs/claude-code/overview)** — the agent
  aki drives (`npm install -g @anthropic-ai/claude-code`)
- **[zellij](https://zellij.dev/)** — only for terminal mode; the installer fetches it if
  it's missing

Linux binaries are built against system OpenSSL. If `aki --version` fails on a minimal
distro, install your distro's `openssl` / `ca-certificates` packages.

## Quick start

```bash
cd ~/workspace/my-project
aki init                              # scan for git repos, create .aki/
aki -p "add rate limiting to the API" # create a task and start the agent
aki ls                                # see every task and its status
aki go rate-limiting                  # jump into a running task's terminal
aki diff rate-limiting                # review the changes across all repos
aki done rate-limiting                # merge the branches, mark the task done
aki clean rate-limiting               # tear down the worktrees and branches
```

Task branches are named `aki/<task>`, so `git branch --list 'aki/*'` finds everything aki
made, in any repo.

## Drive from the browser

```bash
aki login          # one-time device-flow sign-in
aki web auth-fix   # hand this task to the web UI at visor.aki.am
aki go auth-fix    # take it back into the terminal, mid-conversation
```

Terminal and web share one session, so handing a task between them keeps the whole
history. Nothing listens on a public port: a local daemon holds the session and dials
**out** over a single WebSocket.

In the browser you can chat with the agent, approve or deny each tool call, watch its
thinking, review the diff, and commit or merge. Per-task **autonomy** decides how much it
asks: `manual` approves everything, `auto` approves tools but still asks real questions,
`zevs` never pauses.

## Project knowledge

Every session is captured and indexed per project, so later tasks recall what earlier ones
learned instead of rediscovering it.

```bash
aki search "how does token refresh work"          # past sessions + curated docs
aki doc create --title "API Reference" --file docs/API.md
aki learn list                                     # review distilled learnings
```

## Command reference

Run `aki <command> --help` for any of these.

### Tasks

| Command | |
|---|---|
| `aki -p "<prompt>"` | create a task from a prompt and start the agent |
| `aki t new <name> [--repos --base --agent --notes --template]` | create a task without starting it |
| `aki ls` | list tasks and their status |
| `aki start <task>` | start or resume a task in the terminal |
| `aki go <task>` | attach to a running task |
| `aki stop <task>` | pause the agent, committing anything uncommitted so no work is stranded |
| `aki t wait <task> --until <state>` | block until the task is awaiting-input, idle, waiting (either), done or stopped |
| `aki t send <task> "<text>"` | send the task's agent its next prompt |
| `aki t add-repo <task> <repo>` | give an existing task one more of the project's repos — the worktree appears on the task's branch |
| `aki t rename <task> <name>` | rename a task; its branch and worktrees keep their names |
| `aki diff <task> [--stat]` | diff across all the task's repos |
| `aki merge <task> [branch]` | merge the task's branches, leave it open |
| `aki done <task> [branch]` | merge, then mark the task done |
| `aki clean <task> [--force]` | remove worktrees and delete branches |
| `aki summary <task>` | write the task's summary doc |
| `aki t rm <task>` | delete the task and its workspace |
| `aki t hist` | completed task history |

### Projects

| Command | |
|---|---|
| `aki init` | scan the current directory for repos, create `.aki/` |
| `aki add <path>` | add a repo to the current project |
| `aki remove <repo>` | remove a repo from the current project |
| `aki pls` | list projects |
| `aki select <name>` | switch the current project |
| `aki info` | show the current project's repos and tasks |
| `aki analyze` | AI analysis of the workspace, written to `.aki/docs/` |
| `aki status` | quick overview of everything |

### Web & account

| Command | |
|---|---|
| `aki login` / `aki logout` | device-flow sign-in |
| `aki ui` | open the web UI |
| `aki web <task>` | drive a task from the web UI |
| `aki sync` | reconcile local tasks with the backend |

### Knowledge

| Command | |
|---|---|
| `aki search <query>` | search docs and past sessions |
| `aki doc create \| list \| show \| edit \| attach` | manage project docs |
| `aki learn list \| show \| promote \| reject` | browse and curate distilled learnings |
| `aki distill <session>` | distill a session into learnings |
| `aki index` | rebuild the knowledge index |

## Where things live

```
~/.aki/
  config.toml     defaults, agent profiles, hooks
  state.json      projects and tasks — the source of truth
  credentials.json
  daemon.log

<project>/.aki/
  project.toml    the project's repos
  worktrees/<task>/<repo>/   one isolated worktree per repo, per task
  docs/           aki analyze output
```

## Configuration

`~/.aki/config.toml`:

```toml
[defaults]
agent = "claude"          # default agent profile
branch_prefix = "aki"     # task branches are <prefix>/<task>
checkpoint_on_stop = true # commit uncommitted work when `aki stop` pauses a task

[defaults.hooks]
# Run when a browser-driven agent stops working — it finished a turn, or it is
# blocked on a question. $AKI_AGENT_STATE says which; once per transition.
on_agent_idle = ['notify-send "aki: $AKI_TASK is $AKI_AGENT_STATE"']

[[agent_profiles]]
name = "claude"
command = "claude"

[[agent_profiles]]
name = "codex"
command = "codex"
```

Pick a profile per task with `aki t new <name> --agent codex`.

## Running tasks from tasks

An agent has a shell, and `aki` is on it — so an agent can hand work to another
task and wait for it. `aki t wait` answers with an exit code (`0` it happened,
`2` timed out, `3` it never will), which is what lets a chain report a problem
instead of hanging:

```bash
aki t new deploy-fix --notes "Fix the failing deploy check."
aki web deploy-fix                                  # starts the agent on the brief
aki t wait deploy-fix --until waiting --timeout 1800 || exit 1
aki diff deploy-fix --stat
aki t send deploy-fix "Looks right. Run the tests and report."
```

`--until waiting` covers both ways an agent stops: blocked on a question, and
finished a turn. The `on_agent_idle` hook fires on exactly the same moments.

## Source

This repo distributes releases. The Rust source is not public — if you need a build for a
platform with no published asset, open an issue.

## License

[Apache License 2.0](./LICENSE).
