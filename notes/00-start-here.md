# Start here — a guided CAP homelab

Start here once. Set up a separate Docker replay worktree so each experiment runs the right version of the app without disturbing your original checkout.

[All lessons](README.md)

## What you will build and understand

One ticket office becomes two. First they double-book a seat. Then they share an authority and lose availability when that authority cannot be reached. Finally they accept local bookings and exchange records, converging on a conflict after a partition.

You will run the original committed Ruby code at each stage. Read the code changes, predict an outcome, issue requests, compare the result, and explain the result before advancing. Kubernetes is intentionally later: running more containers does not by itself implement a consistency protocol.

**Rule:** A1 is one seat for one event, not one seat per office. At most one customer should receive a confirmed booking.

## Requirements

- Ubuntu WSL with working Docker Desktop integration (or an equivalent Linux Docker setup).
- Docker Compose supporting `!override` (2.24.4 or later; tested version is in the validation report).
- Git, Bash, and curl. These are shell/development tools, not host application runtimes.
- Internet access for Docker images and gems on the first build. Subsequent builds may reuse cached layers.
- Free local ports 14567 and 14568 for this tutorial.

Ruby, Bundler, and gems run inside Docker. No host Ruby, Node, database, Python, jq, or Kubernetes installation is required to follow these Docker lessons. Existing k3d/kubectl are used only in future lessons.

## One-time setup: original checkout and a replay worktree

Keep this documentation open in your original checkout. If you do not have the repo, clone it first:

```bash
git clone https://github.com/aruprakshit/cap-kub-lab.git
cd cap-kub-lab
```

If you already have the repo, just enter its directory; do not clone over it. The README and notes are included in the shared repository. If `notes/` is missing from an older checkout, update your main checkout to the documented version before proceeding; the early historical lesson commits predate these notes.

Use **Bash** for this tutorial. In an Ubuntu terminal currently using zsh, enter:

```bash
bash
```

Then, from the original repo root:

```bash
export TUTORIAL_SOURCE="$(pwd -P)"
export TUTORIAL_WORK="$HOME/cap-kub-tutorial"

git rev-parse --show-toplevel
git cat-file -t b5086f1
```

The first command should print the original repo path. The second should print `commit`. If the commit is missing from a shallow clone, fetch the history before continuing (`git fetch --unshallow` applies only to shallow clones).

Create a separate source checkout:

```bash
git worktree add --detach "$TUTORIAL_WORK" b5086f1
cd "$TUTORIAL_WORK"
source "$TUTORIAL_SOURCE/notes/tutorial-shell.sh"
```

Run `git worktree add` only once. If that path already exists, inspect `git -C "$TUTORIAL_SOURCE" worktree list` and use the existing matching worktree; do not delete or overwrite an unrelated directory. Detached means this checkout points directly to a recorded commit. Your original main branch and application files remain untouched.

Sourcing the helper defines three functions; it does not start containers:

| Function | What it does |
| --- | --- |
| `dc ...` | Runs Docker Compose with project `cap-kub-tutorial` and the checkpoint's tutorial overlays |
| `wait_for_offices` | Waits for expected host health endpoints after startup; stops with an error if not ready |
| `ask_b /path [JSON]` | Runs a temporary Ruby HTTP client on B's access network; available from lesson 08 onward |

You can inspect the complete helpers at any time:

```bash
cat "$TUTORIAL_SOURCE/notes/tutorial-shell.sh"
```

## Why use an overlay?

Historical source uses host ports 4567/4568 and an explicitly named coordination network. Reusing those could collide with your existing lab. Our overlays replace host ports with 14567/14568 and the shared network name with `cap-kub-tutorial-coordination`. Application port 4567, peer names, request logic, and historical source remain unchanged.

`dc` expands to a command like:

```bash
docker compose -p cap-kub-tutorial \
  -f compose.yml \
  -f "$TUTORIAL_SOURCE/notes/fixtures/two.yml" \
  -f "$TUTORIAL_SOURCE/notes/fixtures/networks.yml" \
  config
```

The source Compose file comes first; later files override it. `!override` replaces the ports list instead of accidentally retaining the original published ports. Lesson 10 also uses a mode overlay so you need not edit a historical file merely to replay authority mode.

See [Compose merge rules](https://docs.docker.com/reference/compose-file/merge/) and [Git worktrees](https://git-scm.com/docs/git-worktree).

## The command order used throughout

```text
Stop old tutorial containers -> select the intended commit -> choose mode
-> validate Compose -> build/start -> wait for health -> run requests
```

- Stop BEFORE changing commits: the old Compose definition describes the old stack.
- Select the commit BEFORE building: Docker copies that version of app.rb.
- Choose the mode BEFORE creating containers: environment variables are set at creation.
- Wait for health BEFORE booking: container started does not mean Puma is already listening.
- Start empty when the experiment says so: a previous booking changes the expected response.
- Never restart between partition and recovery: restart erases memory and invalidates that comparison.

Follow one lesson at a time. If a checkpoint check fails, stop and use [troubleshooting](14-troubleshooting.md); do not keep running dependent commands.

## Shell and output conventions

All command blocks are Ubuntu Bash unless explicitly labeled Windows PowerShell. Paste commands without the `$`, `➜`, or `PS>` prompts, without Markdown backticks, and without adding Markdown link formatting around URLs. A trailing backslash joins lines; do not put spaces after it.

`curl -i` displays HTTP status and response headers. `-H` sets a request header; `-d` supplies the JSON body and makes curl use POST. GET is used when there is no body. Expected business rejection `409` and dependency failure `503` are different from curl connection errors. Header case, dates, and body length may vary. UUIDs will vary. Compare semantic fields and IDs within your run.

The tutorials use a detached server (`up -d`) so all commands can run in one terminal. `dc logs -f` follows logs; Ctrl+C stops following, not the containers. `dc down --remove-orphans` actually stops/removes this tutorial stack and erases its in-memory bookings.

## Resume in a new terminal

Functions and exported variables do not survive closing the shell. Enter Bash, set the original path explicitly, then:

```bash
export TUTORIAL_SOURCE="$HOME/cap-kub-lab"
export TUTORIAL_WORK="$HOME/cap-kub-tutorial"
cd "$TUTORIAL_WORK"
source "$TUTORIAL_SOURCE/notes/tutorial-shell.sh"
```

Adjust TUTORIAL_SOURCE if your original clone is elsewhere. For lesson 10 also set `export TUTORIAL_MODE=authority`; other local-mode lessons use `export TUTORIAL_MODE=local`. The wrapper supports only the six recorded source checkpoints, to catch accidental execution against an unrelated version.

## Finish or pause

To preserve process memory for a short pause, leave containers running. To stop completely:

```bash
dc down --remove-orphans
cd "$TUTORIAL_SOURCE"
```

The worktree can remain for future replay. Do not use broad Docker prune commands. The tutorial helper targets only project `cap-kub-tutorial`; your separate `cap-kub-lab` project is not stopped by it.

Continue to [lesson 01](01-container-setup.md).

---

Next: [01 — A Ruby application without installing Ruby on Ubuntu](01-container-setup.md).
