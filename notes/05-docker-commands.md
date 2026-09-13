# 05 — Command reference and the original build history

This page is a reference, not a script to execute in order. For the next experiment, go to [lesson 06](06-authoritative-office.md). All tutorial commands use the helpers from [start here](00-start-here.md).

## What each Docker command changes

| Command | Purpose | Effect on bookings |
| --- | --- | --- |
| `dc config` | Print/validate merged configuration; no server starts | None |
| `dc up -d --build` | Build images, create/recreate changed services, start in background | Recreated processes lose memory |
| `dc up -d --build --force-recreate` | Recreate even unchanged services | Clears both offices' memory |
| `dc ps -a` | Inspect running and stopped containers | None |
| `dc logs --tail=30` | Read recent logs | None |
| `dc logs -f` | Follow logs; Ctrl+C only stops following | None |
| `dc stop office-a` | Stop A's process, retain its container | A loses volatile state |
| `dc start office-a` | Start that stopped container; no image rebuild | Starts A with empty state |
| `dc restart office-a` | Stop/start A, using its existing image | Clears A's memory |
| `dc down --remove-orphans` | Stop/remove tutorial containers and networks, including obsolete services in this project | Clears all tutorial bookings |
| `docker network disconnect NETWORK ID` | Remove a running container's endpoint | Does not restart Ruby |
| `docker network connect --alias office-b NETWORK ID` | Restore an endpoint and peer alias | Does not restart Ruby |
| `docker inspect ID` | Read configuration/runtime metadata | None |
| `docker run --rm ...` | Create a temporary container, remove it on exit | Does not restart either office |

An image is a template, a container is a running/stopped instance, and a process owns our in-memory hash. Removing a client container does not remove the app image or the offices. A port mapping in metadata does not prove a functioning forwarding path.

## Plain Docker versus the tutorial wrapper

`dc` is not a Docker command. It is a transparent Bash function wrapping `docker compose` with a separate project name and documented overlay files. See its definition using `declare -f dc`.

For example, original lesson commands used `docker compose up --build` and host port 4567. The tutorial uses `dc up -d --build` and port 14567. These deliberate execution-environment differences do not modify app.rb or its internal port.

## Original project creation commands

These record how the project was authored; they are NOT required during historical replay:

```bash
mkdir -p ~/cap-kub-lab
cd ~/cap-kub-lab
```

The learner manually wrote Dockerfile, app.rb, Gemfile, and Compose. A new reader gets their complete versioned contents through the worktree. There are no omitted code fragments to assemble before the replay.

Environment checks used:

```bash
docker info --format '{{.OSType}}'
docker compose version
k3d version
kubectl version --client
```

Initial direct gem installation, later replaced by Bundler:

```dockerfile
RUN gem install sinatra -v 4.1.1 --no-document \
    && gem install puma -v 6.6.0 --no-document \
    && gem install rackup -v 2.2.1 --no-document
```

Those were image-build instructions, not host installation. The full Docker-based lock-generation command and explanation are in [lesson 01](01-container-setup.md). The committed lockfile is used on replay; no regeneration is needed.

Original build/start, reset, and transition commands:

```bash
# Original single-service stage:
docker compose up --build
docker compose restart office

# After renaming office to office-a and office-b:
docker compose up --build --remove-orphans

# Later fresh starts and background execution:
docker compose down --remove-orphans
docker compose up -d --build
```

These belong to different source versions. They are collected for reference, not intended to be run against the latest code as one sequence.

## How to inspect code evolution

From the tutorial worktree:

```bash
git log --all --oneline
git show b5086f1:compose.yml
git diff b5086f1 0aedb7a -- compose.yml
git diff 0aedb7a 981fa2e -- app.rb
git diff 47c24dd b2425cb -- app.rb
git diff b2425cb e4b07a5 -- app.rb
```

These read history without changing files. `git switch --detach COMMIT` changes the replay worktree and is only used after stopping its previous containers. If it refuses due to local edits, preserve/review those edits; do not use a destructive reset to force the tutorial forward.

## Commit discipline

In development: implement one learning, test it, explicitly mark a checkpoint, commit code, then write notes against the resulting hash. In replay: no new source commit is necessary merely for running an experiment. Do not commit generated bookings; they exist only in memory.

README.md and the tutorial notes are now tracked and shared in Git. Ordinary `git add` stages edits to tracked files even if an existing ignore pattern matches them. If adding a new note, check `git status` and `git check-ignore` if it does not appear; ignore patterns can still affect new, untracked files.
