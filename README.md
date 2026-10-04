<!--
  This file is the source of truth for the PUBLIC repo's README
  (a-knowledge-interface/aki-cli). The release workflow copies it there on every
  release, so edit it HERE, in the source repo, never on the public side: an edit
  made there is overwritten by the next release.
-->

# aki

**Put AI to work across all your repos at once.**

`aki` hands a coding task to an AI agent (Claude Code, Pi or Codex) that works across every
repository in your workspace simultaneously. Each task gets its own git worktree and branch in each repo, so
the agent's work never touches your checkout and several tasks can run in parallel. Drive
a task from your terminal, from the browser, or both: it's the same session either way.

```bash
cd ~/workspace/my-project
aki init
aki -p "fix the auth bug in the login flow"
```

This repository distributes the **released `aki` binary**. It is a single self-contained
executable: no Rust toolchain, no Node runtime, no `node_modules`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/a-knowledge-interface/aki-cli/main/install.sh | bash
```

The installer downloads the binary for your platform from
[Releases](https://github.com/a-knowledge-interface/aki-cli/releases), verifies its
checksum and installs it to `~/.local/bin`. aki's skills, which teach an agent to search
project knowledge and save what it learns, are built into the binary and given to every
session aki starts; the installer also keeps a copy in `~/.claude/skills` for Claude Code
sessions you start yourself, and never overwrites a skill you have edited.

To upgrade, run the same command again. The binary is replaced atomically by rename, so a
running `aki` daemon keeps its old build until it restarts. Restart it once after upgrading:

```bash
systemctl --user restart aki-daemon.service                # Linux
launchctl kickstart -k gui/$(id -u)/com.aki.daemon         # macOS
```

Upgrading from 0.8.x? Read the
[0.9.1 upgrade notes](./CHANGELOG.md#091--2026-10-04): tasks made before 0.9 need
`aki doctor <task> --repair-context` once before their next start.

| Variable | Default | |
|---|---|---|
| `AKI_VERSION` | latest release | pin a version, e.g. `0.9.1` |
| `AKI_INSTALL_DIR` | `~/.local/bin` | where the binary goes |
| `AKI_SKILLS_DIR` | `~/.claude/skills` | where the optional global copy of the skills goes |
| `AKI_NO_SKILLS` | | set to `1` to skip skills |

Prefer to do it by hand? Download `aki-<platform>.tar.gz` from the release, verify it
against the published `.sha256`, and move `aki` onto your `PATH`.

### Platforms

| Platform | Status |
|---|---|
| `linux-x64` | published |
| `macos-arm64` | published (macOS 11+) |
| `macos-x64` | published (macOS 11+) |
| `linux-arm64` | not yet built |

The installer already knows all four; it will tell you clearly if a release has no asset
for your platform yet.

**macOS note:** the curl installer above works as-is. If you instead download a tarball
in a **browser**, Gatekeeper quarantines it and macOS will refuse to run the binary.
Clear it with `xattr -d com.apple.quarantine aki-macos-arm64.tar.gz` before extracting
(the binaries are ad-hoc signed, not notarized).

### Prerequisites

Not bundled. The installer checks for them and tells you what's missing:

- **git**: aki works through git worktrees
- **a coding agent**, installed and signed in. Any one of these is enough:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview):
    `npm install -g @anthropic-ai/claude-code`
  - [Pi](https://pi.dev): `curl -fsSL https://pi.dev/install.sh | sh`
  - [Codex](https://developers.openai.com/codex): `npm install -g @openai/codex`
- **[zellij](https://zellij.dev/)**: only for terminal mode; the installer fetches it if
  it's missing

Linux binaries are built against system OpenSSL. If `aki --version` fails on a minimal
distro, install your distro's `openssl` / `ca-certificates` packages. macOS binaries use
the system Security framework, so there is nothing extra to install.

## Quick start

```bash
cd ~/workspace/my-project
aki init                              # scan for git repos, pick the agent, create .aki/
aki -p "add rate limiting to the API" # create a task and start the agent
aki ls -t                                # see every task and its status
```

`aki ls -t` prints one row per task:

```
#   Project  Task                   Repos                Status          Age
1   acme     add-api-rate-limiting  backend, shared-lib  running         2m
2   acme     auth-fix               backend, frontend    idle · waiting  1d
```

The `#` column is the task's **stable number**: one sequence per project, shared with the
web, assigned once and never reused, so it never shifts when a filter hides rows or another
task is removed. A task created offline shows `unnumbered` until aki next syncs. Every
command that takes a task name also takes that number:

```bash
aki go 1                        # by number, the # column above
aki go add-api-rate-limiting    # by name: the same task, number 1
aki go acme/add-api-rate-limiting   # by project and name, from any directory
```

The status column reads `ready`, `starting`, `running` (a turn in flight), `idle`,
`stopped` or `done`, and `· waiting` is appended when the agent is blocked on you: a
question or a tool permission. `idle · waiting` is the row that needs you. For a compact
overview across every project, `aki status` uses one-character markers instead: `*`
running, `!` stopped, `-` ready, and `?` when the agent is blocked on you.

```bash
aki diff 1                # review the changes across all repos
aki done 1                # merge the branches, mark task 1 done
aki rm -t 1               # stop, close, then delete it entirely (asks first)
```

Task branches are named `aki/<task>`, so `git branch --list 'aki/*'` finds everything aki
made, in any repo. (A task created in the web also carries its number: `aki/7-auth-fix`.)

## Drive from the browser

```bash
aki login     # one-time device-flow sign-in
aki web 2     # hand task 2 (auth-fix) to the web UI at visor.aki.am
aki go 2      # take it back into the terminal, mid-conversation
```

Terminal and web share one session, so handing a task between them keeps the whole
history. Nothing listens on a public port: a local daemon holds the session and dials
**out** over a single WebSocket.

In the browser you can chat with the agent, approve or deny each tool call, watch its
thinking, pick the model and reasoning effort from the ones that machine's agent offers,
review the diff, and commit or merge. Per-task **autonomy** decides how much it asks:
`manual` approves everything, `auto` approves tools but still asks real questions, `zevs`
never pauses. Stop ends a turn and Skip clears a stuck question, without killing the
session.

You can start from the browser too: the **+** in the Projects header makes a new project.
Pick the machine, browse or type the folder, and it runs the real `aki init` there. Only
you can do this on your machines; nobody you share a task or project with can browse your
filesystem through it.

## Choose the agent

aki drives three coding agents. A project has a default, and each task or agent can name
its own:

```bash
aki init --agent pi                        # this project's default (init asks if you have several)
aki create -t fix-login --profile codex    # one task on another agent
aki create -a reviewer --profile claude    # an agent's own choice
```

Without a choice a new task uses the project's default, then the machine's
(`defaults.agent`). The choice is fixed when the task is created. In the web, the same
choice is the harness picker on New task and New agent, which also shows whether each agent
is installed and signed in on that machine.

| Agent | Terminal | Web | Manual approvals |
|---|---|---|---|
| Claude Code | yes | yes | yes |
| Pi | yes | yes | from the web (aki's gate extension) |
| Codex | no (`aki go` refuses) | yes | no: Auto (sandboxed) or Full; new Codex work starts at Auto |

`aki link-chatgpt` gives Pi the ChatGPT sign-in Codex already has on this machine, so Pi can
use a ChatGPT Plus or Pro subscription. `aki doctor <task>` explains what aki believes about
a task's session: which agent, whether it is installed and signed in, where the transcript
is, and what is driving it. `aki adopt <session-id> -t <task>` attaches a session you ran
outside aki to a task, so it becomes searchable project knowledge.

## Agents

The AI session that drives a task ends with the task. **Agents** are the persistent kind:
a named teammate with standing instructions, a model, an autonomy level, and one
continuous conversation that carries from one assignment to the next. Create one per role,
such as a release runner, a nightly monitor or a reviewer, and hand it work whenever that
role is needed instead of re-explaining the role every time.

An agent is a session like a task is, so it opens the same way. `aki send` queues a job
and the agent works through its queue in order; `aki start -a` drops you into that same
conversation to type in directly, which is what you want when the agent has been getting
something wrong and you would rather show it than describe it.

```bash
aki create -a watchtower \
  --description "Watches production; reports what needs a human." \
  -f watchtower.md --autonomy auto

aki send watchtower "Anything unusual since yesterday?" --wait

# Or sit in the conversation yourself, the way you would a task:
aki start -a watchtower

# Standing work, written in plain language. Parsed exactly or refused, never guessed:
aki agent schedule watchtower --when "every weekday at 09:00" "Run the morning checks."

aki agent jobs watchtower     # its queue and what recently ran
```

- **Work is a queue, not a chat.** Talking to an agent never starts work by itself. Asks,
  schedules, and assigned tasks all enqueue **jobs**, and the agent runs them one at a
  time, in order.
- **Agents can own tasks.** Assign a task to an agent, at creation or later from the task
  chat, and it drives the whole arc: it briefs the task's session, lets the work happen in
  the task's own isolated worktrees like any other task, reviews the result, and reports
  back.
- **Schedules run without you.** Each firing queues a normal job, and a window missed
  while the machine was asleep is counted and shown, never silently skipped.
- **Edits land live.** `aki agent edit` reaches a *working* agent at its next pause, with
  no restart.
- **Answers come back.** Asked from inside another aki task or agent session, an agent
  writes its answer back into that session when the job finishes, even from another of your
  machines. `--wait` prints it instead.
- **Pinned to a machine.** An agent runs on one of your machines, for good: the one you
  created it on, or the one you name with `--machine <name>`. `aki ls -a` shows where each
  runs and whether that machine is online, and `aki start -a` elsewhere refuses. Retiring
  with `aki close -a` keeps the history: re-creating the name restores it.

**Personal agents** are yours rather than a project's. `aki create -a browser --mine` makes
one; you can give it work from any project you own, and nobody else can use it. A browser
agent on your laptop is the typical case: every task in your projects can hand it a page
and get the answer back.

```bash
aki create -a browser --mine -f browser.md   # runs on this machine
aki ls -a --mine                             # your personal agents
aki send browser "Summarise https://example.com" --wait
```

A project's agents take work from that project only. `aki send <name>` looks in the current
project first, then your personal agents; `project/name` and `me/name` say exactly which.

Agents appear in the web UI too, under each project and under **My agents**, each with its
status (green working, blue idle), the machine it runs on, its queue, its schedules, and
its chat.

## Project knowledge

Every session is captured and indexed per project, so later tasks recall what earlier ones
learned instead of rediscovering it.

```bash
aki search "how does token refresh work"          # past sessions + curated docs
aki create -d "API Reference" --file docs/API.md
aki learn list                                     # review distilled learnings
```

## Command reference

Run `aki <command> --help` for any of these. Everywhere `<task>` appears you may write the
task's name, its `acme/name` form, or its number from `aki ls -t`.

### Tasks

| Command | |
|---|---|
| `aki -p "<prompt>"` | create a task from a prompt and start the agent |
| `aki create -t <name> [--repos \| --no-repos] [--base --profile --notes --template]` | create a task without starting it |
| `aki ls -t` | list tasks and their status |
| `aki start <task>` | start or resume a task in the terminal |
| `aki go <task>` | attach to a running task |
| `aki stop <task>` | pause the agent; the worktrees stay exactly as they are |
| `aki close <task>` | stop it and mark it closed, keeping every change; it can start again |
| `aki wait <task> --until <state>` | block until the task is awaiting-input, idle, waiting (either), done or stopped |
| `aki send <task> "<text>"` | send the task's agent its next prompt |
| `aki repo add -t <task> <repo>` | give an existing task one more of the project's repos; the worktree appears on the task's branch |
| `aki rename -t <task> <name>` | rename a task; its branch and worktrees keep their names |
| `aki diff <task> [--stat]` | diff across all the task's repos |
| `aki merge <task> [branch]` | merge the task's branches, leave it open |
| `aki done <task> [branch]` | merge, then mark the task done |
| `aki summary <task>` | write the task's summary doc |
| `aki rm -t <task>` | stop it, close it, then delete the task and its workspace (asks first) |
| `aki hist` | completed task history |
| `aki doctor <task> [--repair-context]` | explain the task's session; `--repair-context` regenerates its instructions file |
| `aki adopt <session-id> -t <task>` | attach a session you ran outside aki to a task |

### Agents

| Command | |
|---|---|
| `aki create -a <name> [--description --autonomy --model --profile] [-i \| -f]` | create an agent; `--description` is the one line callers see, `-f` reads instructions from a file |
| `aki create -a <name> --mine` | a personal agent, usable from any project you own |
| `aki create -a <name> --machine <name>` | run it on another of your machines (default: this one) |
| `aki start -a <name>` | open the agent's conversation in a terminal and type in it directly |
| `aki ls -a [--mine \| -p <project>]` | agents, where each runs and whether that machine is online |
| `aki show -a <name>` | one agent in full: instructions, autonomy, model, harness, machine |
| `aki agent edit <name>` | change instructions, autonomy, model or description; `default` clears an explicit choice |
| `aki send <name> "<prompt>" [--wait --timeout --autonomy]` | queue work (`me/name`, `project/name` to be exact); `--wait` blocks and prints the result |
| `aki agent jobs <name>` | the agent's queue and what recently ran |
| `aki agent cancel <name> <seq>` | drop a job that has not started yet |
| `aki agent schedule <name> [--when \| --every \| --daily] [--tz --autonomy]` | standing work; no flags lists, `--clear` removes all |
| `aki close -a <name>` | retire an agent; history survives and re-creating the name restores it |

### Projects

| Command | |
|---|---|
| `aki init [-n <name>] [-d <folder>] [--agent <a>] [--no-repos]` | scan a folder for repos and register it as a project: the current directory unless `-d` says otherwise. A name that isn't a slug is folded (`My Workspace` → `my-workspace`), and a name another folder already holds is refused |
| `aki repo add <path>` | register a repo with the current project |
| `aki repo ls` | the project's repos |
| `aki repo rm <repo> [-f]` | deregister a repo; the repo itself is left untouched |
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
| `aki link-chatgpt [--force]` | give Pi the ChatGPT sign-in Codex already has |

### Knowledge

| Command | |
|---|---|
| `aki search <query>` | search docs and past sessions |
| `aki create -d <title> --file <f>` | add a project doc |
| `aki ls -d`, `aki show -d <id>`, `aki doc edit <id>` | list, read and update docs |
| `aki attach <doc> -t <task>` / `-a <agent>` | pin a doc to a task or give it to an agent |
| `aki learn list \| show \| promote \| reject` | browse and curate distilled learnings |
| `aki distill <session>` | distill a session into learnings |
| `aki index` | rebuild the knowledge index |

## Where things live

```
~/.aki/
  config.toml     defaults, agent profiles, hooks
  state.json      projects and tasks, the source of truth
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
agent = "claude"           # the machine's default agent: claude, pi, codex or a profile
branch_prefix = "aki"      # task branches are <prefix>/<task>
checkpoint_on_stop = false # true: `aki stop` also commits uncommitted work on the task's branch

[defaults.hooks]
# Run when a browser-driven agent stops working, having finished a turn or
# blocked on a question. $AKI_AGENT_STATE says which; once per transition.
on_agent_idle = ['notify-send "aki: $AKI_TASK is $AKI_AGENT_STATE"']

# Only needed to run an agent differently: a wrapper script, a pinned path, extra env.
# `kind` says which agent it is; without it a profile is Claude.
[[agent_profiles]]
name = "pi-work"
kind = "pi"
command = "/opt/pi/bin/pi"
```

`claude`, `pi` and `codex` need no profile: `aki create -t <name> --profile codex` just
works. Name a profile the same way to use it.

## Running tasks from tasks

An agent has a shell, and `aki` is on it, so an agent can hand work to another
task and wait for it. `aki wait` answers with an exit code (`0` it happened,
`2` timed out, `3` it never will), which is what lets a chain report a problem
instead of hanging:

```bash
aki create -t deploy-fix --notes "Fix the failing deploy check."
aki web deploy-fix                                  # starts the agent on the brief
aki wait deploy-fix --until waiting --timeout 1800 || exit 1
aki diff deploy-fix --stat
aki send deploy-fix "Looks right. Run the tests and report."
```

`--until waiting` covers both ways an agent stops: blocked on a question, and
finished a turn. The `on_agent_idle` hook fires on exactly the same moments.

## Source

This repo distributes releases. The Rust source is not public. If you need a build for a
platform with no published asset, open an issue.

## License

[Apache License 2.0](./LICENSE).
