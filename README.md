# CAP Kubernetes homelab

A step-by-step distributed-systems tutorial using a Ruby/Sinatra ticket office in Docker. No host Ruby or database installation is needed.

**[Start the tutorial](notes/00-start-here.md)** · **[Lesson index](notes/README.md)** · **[Troubleshooting](notes/14-troubleshooting.md)** · **[Validation](notes/15-validation.md)**

You will observe:

1. One office preventing a second booking.
2. Two independent offices confirming the same seat.
3. A fixed authority coordinating decisions but becoming unavailable to an isolated office.
4. Asynchronous replication retaining conflicting confirmations after recovery.
5. Why Docker Desktop's host-forwarding path can fail independently of a healthy application.

The runnable lessons use verified historical commits in a separate worktree. Tutorial host ports are **14567/14568**, distinct from the original lab's 4567/4568. Each lesson explains its starting state, commands, order, expected results, and recovery. Read the setup before executing commands from later lessons.

Current application source: `e4b07a5`. It has local/authority modes, in-memory booking records, a duplicate-safe receiver, and periodic replication. There is no durable storage or automatic business conflict resolution. The Kubernetes continuation now covers [k3d, the first Deployment, and Pod replacement](notes/17-k3d-deployment-and-recovery.md), with an optional [Headlamp dashboard](notes/16-headlamp-dashboard.md). These steps were verified by the learner at commit 271f190; they were not part of the earlier automated Docker tutorial validation.

## Project files

| File | Role |
| --- | --- |
| app.rb | Booking rules, forwarding, record receiver and sender (depending on checkpoint) |
| Gemfile / Gemfile.lock | Direct dependencies and resolved versions |
| Dockerfile | Ruby runtime, Bundler installation, application startup |
| compose.yml | Offices, environment, ports, networks |
| notes/ | Complete learning sequence and evidence |
| notes/tutorial-shell.sh | Explained tutorial command wrappers |
| notes/fixtures/ | Compose overlays isolating replay ports/networks and mode |

## Sharing the tutorial

The README and tutorial notes are tracked in Git and available on GitHub. Clone the repository to get both the application and the documentation, then follow [Start here](notes/00-start-here.md).

The Ruby application Kubernetes sequence continues with [Service discovery](notes/18-service-discovery.md), [two offices sharing one authority](notes/19-two-offices-in-kubernetes.md), and [a NetworkPolicy partition and recovery](notes/20-kubernetes-network-partition.md). The partition lesson records learner-verified results at `e267954`.
