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

## [Unreleased]

## [0.9.5] — 2026-10-06

0.9.4 was tagged but never published: a check failed on macOS before release. 0.9.5 is the
first release with everything below.

### Changed

- **Work reaches your machine as it happens.** The aki service now tells a connected machine
  when there is something for it, so the machine no longer has to keep asking:
  - a new job for an agent on it starts within about a second;
  - a result an agent finished for one of its sessions arrives within about a second;
  - a task removed on the web is removed from the machine within about a second, where it
    used to take up to a minute.

  While connected, the machine's background checks run much less often: about 14 requests
  a minute when idle, against 32 before. Against an older aki service, everything runs at
  the old pace.
- **Codex agents in Auto mode can do what Claude agents do inside the project:**
  - use the network;
  - read and write the whole project folder;
  - commit in their task's worktrees;
  - run any `aki` command, `aki create -t` included.

  Outside the project and aki's own folder (`~/.aki`), files stay read-only. Zevs is
  unchanged and still runs Codex with no limits.

### Fixed

- **Codex agents in Auto mode could not use aki.** Every `aki` command they ran failed with
  "Dns Failed … Temporary failure in name resolution", and a commit in a task's worktree
  failed with "Read-only file system".
- **A machine whose connection to the service died silently** looked connected to itself
  while the web could not reach it. It now notices within 45 s and reconnects. After a
  connection that was healthy, it reconnects within seconds rather than after its longest
  wait.
- **The web chat finds the right way to send a message** to a Claude or Codex session
  without asking first, so each message makes one request fewer.

### Upgrading

- **Nothing to do.** A running daemon switches to 0.9.4 by itself once it is idle (from
  0.9.2 on).
- **A Codex session that is already running keeps its old limits** until it is started
  again.
- **Tools that keep caches in your home folder may fail inside a Codex agent in Auto
  mode**, for example npm in `~/.npm` or cargo in `~/.cargo`, because the home folder outside
  the project stays read-only. Run such an agent in Zevs.

## [0.9.3] — 2026-10-05

0.9.2 was tagged but never published: the release could not be pushed to this repository.
0.9.3 is the first release with everything below.

### Security

These are fixed in the aki service, so they apply whichever aki version you run.

- **A session could be addressed through someone else's copy of its id.** Anyone who knew a
  session id and a machine's id could plant a task of their own carrying that session id.
  They could then send messages into that session on its owner's machine, or read its live
  events and history. Sessions are now resolved on the machine they are addressed to, for
  the caller, and capturing a session id that belongs to a project you are not a member of
  is refused. A copy captured while you were still a member stops working once you are
  not.
- **Any member's machine could report on another machine's agent job.** That covered a
  viewer's machine too: it could finish a running job with text of its choosing, which was
  then delivered to whoever asked, or put the job back in the queue. Only the agent's own
  machine can now.
- **Viewers can no longer create agents.** A viewer of the asking project can no longer
  read the job, and turning on reply-back needs current access to the asking session.

### Added

- **Upgrades take effect by themselves.** The background daemon notices when its binary
  has been replaced, checks the new one runs, and switches to it in place as soon as
  nothing is running on it: no turn in flight, no question or approval waiting on you, no
  agent job, nothing said for a minute. Nothing is cut off. A web session that was resting
  restarts on your next message. `AKI_NO_SELF_UPGRADE=1` turns this off.
- **The installer moves the daemon to the new version.** If no daemon is running, it starts
  one. A 0.9.3 or later daemon is left to switch by itself. An older one is restarted right
  away when no web session is running; otherwise the installer prints the one command to
  run later. A machine that is not signed in is left alone. `AKI_NO_DAEMON=1` skips this
  step.
- **Install from aki.am.** `curl -fsSL https://aki.am/install.sh | bash` runs the same
  installer as before, served from aki.am. The GitHub URL keeps working.

### Fixed

- Typing into a stopped Claude Code or Codex task from the web reopens it again. Since 0.9.1
  the message was kept as "not sent". A stopped Pi task still has to be started first.
- The first web message to a new agent starts it. It used to be kept as "not sent".
- A personal agent's status (working, waiting on you) now reaches the web.
- While the daemon waits to switch to a new version behind a long request, other messages
  are no longer turned away for minutes.
- A chat open on the web no longer stops updating when its machine reconnects, which a
  self-upgrade does.
- Every task's instructions told the agent to "pass `-p <project>`". On its own,
  `aki -p` creates a task, so the instructions now say `AKI_PROJECT=<project>`.
- The empty task list hinted at `aki ls --all`, which fails. It now says `aki ls -t --all`.
- Replies from an agent are described as they work. They reach a session while aki is
  driving it, or the next time it does within seven days. A session open only in a terminal
  does not get them in the meantime.

## [0.9.1] — 2026-10-04

0.9.0 was tagged but never published: its macOS build failed its own tests. 0.9.1 is the
first release with everything below.

aki now drives three coding agents (Claude Code, Pi and Codex) and lets agents work for you
across projects: personal agents that you can use from any project you own, a choice of the
machine each agent runs on, and answers that come back to whoever asked.

### Upgrading

- **Restart the daemon once after installing.** The installer replaces the binary, but a
  running daemon keeps its old code until it restarts:
  `systemctl --user restart aki-daemon.service` on Linux,
  `launchctl kickstart -k gui/$(id -u)/com.aki.daemon` on macOS. Personal agents in
  particular only become available on a machine after its daemon has restarted on 0.9.1.
- **Tasks made before this version ask once before their first start.** aki now owns the
  instructions file it writes into a task (`CLAUDE.md`, or `AGENTS.md` for Codex) and never
  overwrites one it cannot prove it wrote, because you may have edited it. Files from 0.8.x
  have no such record, so `aki start`, `aki go` and the web refuse with "refusing to replace
  foreign or edited instructions". Look at the file, then run
  `aki doctor <task> --repair-context`: it keeps a backup next to it and writes a fresh one.
- **A `[[agent_profiles]]` entry for Codex or Pi needs a `kind`.** An entry without one is a
  Claude profile, so `name = "codex"` with no `kind` ran the `codex` binary with Claude's
  arguments. Add `kind = "codex"` (or `"pi"`), or delete the entry: `--profile codex` and
  `--profile pi` work without any configuration now.
- **New terminal tasks are named without their number.** Their branch and folder are
  `aki/<task>` and `.aki/worktrees/<task>`, not `aki/<n>-<task>`. Existing tasks keep their
  paths. Scripts that built a branch name from the number need updating.
- **A 0.8.31 CLI keeps working** against the service. Personal agents need 0.9.1 on the
  machine that runs them and on any machine that gives them work.

### Added

- **Pi and Codex, next to Claude Code.** Choose the agent a project uses with
  `aki init --agent <claude|pi|codex>`, or per task and per agent with `--profile`, or in the
  web's harness picker. Without a choice a new task or agent uses the project's default, then
  the machine's. The choice is fixed when the task or agent is created.
  - **Pi** runs in the terminal and from the web. aki's gate extension gives it Manual
    approvals, question cards and a write boundary for its file-writing tools. A prompt sent
    from the web is tracked by id, so a retry or reload never sends it twice.
  - **Codex** runs from the web (`aki web`, `aki start --headless`) through
    `codex app-server`, with streamed answers and reasoning, interrupt and questions. It
    cannot hold a tool for approval, so it runs at Auto (sandboxed to the task's worktrees) or
    Full, never Manual, and new Codex tasks and agents start at Auto.
  - **`aki init` lists the agents installed on the machine** with their versions and whether
    they are signed in, uses the only ready one as the project default, and asks when there
    are several.
  - **The web shows each machine's agents** and whether each is installed and signed in, and
    a task whose agent is not installed is refused at launch with the reason.
- **Models and reasoning effort from the machine.** The web's model picker lists what the
  machine's Claude Code, Pi or Codex actually offers, including 1M-context Claude models, and
  a reasoning-effort control offers the levels that model supports. Opus 5 and Opus 4.8 appear
  under previous models when your Claude account accepts them. `aki go` carries the model and
  effort chosen on the web into the terminal.
- **Personal agents.** `aki create -a <name> --mine` makes an agent that lives in your own
  `me` space instead of a project. You can give it work from any project you own, and nobody
  else can use it. `aki ls -a --mine` lists them, `me/<name>` addresses one, and the web lists
  them under **My agents**. Each machine sets up its `me` space (`~/.aki/me`) when its daemon
  starts. `me` is reserved as a project name.
- **Choose the machine an agent runs on.** `aki create -a <name> --machine <name|id>`, or
  **Runs on** in the web. From the terminal the default is the machine you are on. An agent is
  only ever placed on one of your own machines, and it stays there: `aki start -a` on any
  other machine refuses and says where it runs. `aki ls -a` and `aki show -a` name the
  machine.
- **Answers come back to whoever asked.** `aki send <agent> "..."` from inside an aki task or
  agent session writes the agent's answer back into that session when the job finishes,
  including when the agent runs on another of your machines. `--wait` still prints it instead.
  `aki send` finds the agent itself: the current project's first, then your personal agents;
  `project/name` and `me/name` say exactly which. A project agent takes work only from its own
  project's sessions; a personal agent only from its owner's.
- **`aki doctor <task>`** explains what aki believes about a task's session: which agent runs
  it, whether that agent is installed and signed in, where its transcript is, what is driving
  it, and whether its instructions file is aki's. It exits with code 2 when it finds a problem.
  `--repair-context` backs up and regenerates the instructions file.
- **`aki adopt <session-id> -t <task>`** attaches a Claude Code, Pi or Codex session you ran
  outside aki to a task and captures its transcript, so it becomes searchable project
  knowledge.
- **`aki link-chatgpt`** gives Pi the ChatGPT sign-in that Codex already has on this machine,
  so Pi can use a ChatGPT Plus or Pro subscription without its own login. It never replaces a
  login Pi already has unless you pass `--force`.
- **Projects and tasks without repos.** `aki init --no-repos` makes a project from a folder
  with no git repos, and `aki create -t --no-repos` a task that works directly in the project
  folder, with no worktrees and nothing to merge. Without the flag an empty folder is still
  refused, and a terminal now asks instead.
- **Unstick a session from the web.** Stop ends the current turn and Skip drops a question or
  approval that is stuck, without killing the session. A permission reply that never reached
  Claude Code is reported instead of hanging.
- **aki's skills reach every session.** The skills that teach an agent to search project
  knowledge and save what it learns are built into the binary and given to every session aki
  starts, on any of the three agents. The installer's copy in `~/.claude/skills` is now only
  for Claude Code sessions you start yourself.
- **Summaries, distilled learnings and web doc generation follow the project's agent**, on
  Claude Code or Pi.

### Changed

- **Task numbers come from your account.** One sequence per project, shared by the terminal
  and the web, handed out in creation order. A task created offline shows `unnumbered` until
  aki next syncs. A number is never read as a position in the list any more: when any task in
  a project was unnumbered, `aki rm -t 3` could pick the third row rather than task 3.
- **`aki go` and a terminal `aki start` make sure the web has let go first.** They open the
  terminal only once the daemon confirms the web-driven session has stopped, so two writers
  never share one conversation. If that cannot be confirmed, they refuse and say why.
- **`aki ls -a`** shows AGENT, MACHINE and DESCRIPTION, names the machine (with
  `(offline)`), and mentions your personal agents. **`aki show -a`** adds kind, machine and
  harness. **`aki agent jobs`** shows which session asked.
- **An agent keeps its agent program across machines**, and `aki start -a` runs the agent's
  own choice rather than the machine's default.
- **An unknown profile name is refused.** `--profile` or `defaults.agent` naming something
  that is neither a configured profile nor `claude`, `pi` or `codex` used to run Claude
  silently.
- **Daemon refusals say why.** A drive the daemon refused used to be reported as "couldn't
  reach the aki daemon"; the daemon's own reason is now shown.
- `aki close` on a done task leaves it done, and closing again re-sends the close.

### Fixed

- `aki serve --port <anything but 8899>` stopped every running agent session on the machine.
- A web Deny with no message permanently broke a Claude session, and an approval or answer
  aimed at the wrong prompt could leave a turn blocked forever.
- The web model picker could not select a 1M-context Claude model or match the running one,
  and `aki go` dropped the model chosen on the web.
- The web cleared an approval card before the answer had been delivered.
- Clearing an agent's instructions in the web did not reach the running agent.
- An agent job that could not be set up on its machine was retried forever instead of being
  reported as failed.
- The installer deleted skills you had edited in `~/.claude/skills`. It now keeps any skill
  folder it did not install, or that you changed.
- The installer reported a missing prerequisite on a machine with Pi or Codex but no Claude
  Code. Any one of the three is enough.
- `aki init` in a folder named `me` wrote its files before refusing the name.

### Known limitations

- **Codex** cannot be opened in a terminal (`aki go` refuses), and summaries, distilled
  learnings and web doc generation do not run on it yet. `aki analyze` runs on Claude Code
  only.
- **Pi** asks for approvals only when driven from the web. In a terminal its write boundary
  still applies to file-writing tools, but shell commands are not path-limited.
- **`aki link-chatgpt`** is terminal-only.
- **An agent cannot be moved** to another machine, or between a project and `me`.

## [0.8.31] — 2026-09-18

### Added

- **Make a project from the web.** A project is a folder on your machine, so until now one
  could only be born at a terminal with `aki init` in the folder you were standing in — and
  the web's empty Projects page could only tell you to go and do that. The daemon now answers
  two calls the browser makes over the tunnel: one lists the folders on this machine, the
  other runs the real `aki init` on the one you picked. The browser half is the **+** in the
  Projects header. Both are owner-only: nobody you share a task or a project with can read
  your filesystem through them.
- **`aki init --dir <folder>`** initializes a folder you are not standing in.
- **Closing a task, separately from finishing it.** `aki t close <task>` stops the task's
  processes and marks it closed, leaving the worktrees and every change in them exactly as
  they are. It is the honest end for work you are setting down rather than landing: no
  commit, no merge, no judgement about whether the work was any good. A closed task starts
  again like a done one does.
- **Removing a task, and the confirmation it deserves.** `aki rm -t <task>` destroys a task
  outright: worktrees, branches, the local record and the row the web reads. It asks first,
  in as many words: this cannot be undone and uncommitted changes are lost. It refuses on a task that is still open — close it
  first, so that "remove" is never the command you reach for to stop something. The task then
  disappears from `aki ls` and from the web UI on every machine, not just the one you ran it
  on.
- **Stopping a task without ending it.** `aki t stop <task>` shuts down the task's session
  and sidecar processes and leaves everything else alone. It is safe to run on a task that is
  already stopped.
- **`aki start -a <name>` opens an agent's conversation in a terminal.** An agent is a
  session like a task is, so it opens the same way. `aki agent ask` still queues a job and
  the agent works its queue in order; `start -a` drops you into that same continuous
  conversation to type in directly, which is what you want when an agent has been getting
  something wrong and showing it beats describing it.
- **One command to create things:** `aki create -t <name>` for a task, `-a` for an agent,
  `-d` for a doc, each with its own options. The older spellings (`aki t new`, `aki agent
  new`, `aki doc create`) still work exactly as before — they are in scripts and in muscle
  memory — they are just no longer the ones the help teaches.

- **`aki repo add|ls|rm`** replaces `aki add` and `aki remove`. Repos are *registered*, not
  created — `aki repo add` points aki at a git repo that already exists, and `aki repo rm`
  stops pointing at it without touching a single file on disk. `aki repo ls` is new; that
  table was previously only reachable inside `aki info`.
- **Another project's agents are reachable.** Every agent command now takes
  `project/agent` as well as a bare name — `aki agent show acme/watchtower`,
  `aki start -a acme/watchtower` — the same shape tasks have always accepted. `aki agent
  list` takes `-p`, having no name to qualify. Previously, with `AKI_PROJECT` set (as it is
  inside every task worktree) another project's agents could not be reached at all except
  by changing the current project for every shell on the machine.

### Changed

- **`aki task` is gone.** Its last two commands moved: `aki task history` is `aki history`
  (`hist` still works), and `aki task new` was the hidden legacy spelling of `aki create -t`.
  Every task verb now lives at the top level with a kind flag.
- ⚠️ **`aki show` now requires a kind.** `aki show <id>` meant a knowledge chunk; it is
  `aki show -k <id>`. The command now also shows a task (`-t`), an agent (`-a`) or a doc
  (`-d`), so it needed to say which.
- ⚠️ **`aki ls` now requires `-t`, `-a` or `-d`.** A bare `aki ls` errors, naming both. The kind
  is inferred from the name everywhere else — `aki rm auth-fix`, `aki stop watchtower` —
  but a listing has no name to infer from, so it asks rather than defaulting.
- ⚠️ **`aki ls -a` lists AGENTS, not every project's tasks.** `-a` means "an agent"
  across the CLI — `create`, `rm`, `start`, `stop`, `close`, `send` — so `aki ls` follows.
  `--all` keeps its long form and its old meaning; only the short form moved. This is the
  one change here that silently does something different rather than erroring, because both
  spellings still produce a list.

- **"Active tasks" counts were counting things that are not active tasks.** They included
  the agent and doc sessions that live beside real tasks, so `aki status` listed rows like
  `doc-7999cc11…` as active work and `aki pls` counted them — on one machine, 59 active
  tasks for a project that had 44. They also counted *closed* tasks forever, since closing
  moves the intent and deliberately leaves the machine status alone. Both are fixed, and
  the counts now agree with what `aki ls` shows instead of contradicting it.
- **A task that says "running" on a machine that has gone away now says so.** Previously a
  task whose machine went offline mid-run stayed "running" forever, and there was no way to
  tell that apart from work actually in progress. It now reads "was running" once the
  machine has been silent for thirty seconds.
- `aki ls` hides closed, done and removed tasks by default, so the list is what you still
  have open. `--closed` brings the finished ones back, and so does asking for them by name
  with `-s done`. (`--all` is unrelated and unchanged: it widens the list to every project.)

### Fixed

- **`aki init --name` no longer renames the repo under it.** In a single-repo folder the
  name was applied before the repo was detected, so `aki init --name payments` in `~/code/api`
  registered the *repo* as `payments` — and a repo's name is a path component of every
  worktree cut from it. The repo keeps its own folder's name.
- **A project name that isn't a slug is folded instead of quietly breaking the web.** A
  project name is half of every task's address, so a folder like `My Workspace` produced a
  project the web could never reach. It becomes `my-workspace`, and `aki init` says so.
- **`aki init` no longer takes a name another folder already holds.** It used to replace the
  older project in local state, leaving that checkout orphaned — its tasks still resolving by
  name to a project that had moved. It now refuses and names both folders.
- A task removed on one machine no longer reappears the next time an older copy of `aki` on
  another machine syncs.

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
