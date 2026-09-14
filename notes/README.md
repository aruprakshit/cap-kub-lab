# CAP homelab — tutorial index

Start with [00 — setup and conventions](00-start-here.md), even if you already have the original lab running. The tutorial uses its own worktree, Docker project, ports, and networks. Complete commands in order; later code cannot reproduce all earlier behavior.

| Lesson | Source checkpoint | What it adds | Expected end state |
| --- | --- | --- | --- |
| [01 Containers and dependencies](01-container-setup.md) | b5086f1 | Understand the build inputs | Tools and config checked |
| [02 One office](02-one-office.md) | b5086f1 | Book, reject, restart | One empty running office |
| [03 Mutex and snapshots](03-mutex-and-snapshots.md) | b5086f1 | Understand process-local coordination | No state change |
| [04 Independent offices](04-two-offices.md) | 0aedb7a | Separate memory causes double booking | Alice at A, Bob at B |
| [05 Command reference](05-docker-commands.md) | Reference | Explain lifecycle and original commands | No required action |
| [06 Fixed authority](06-authoritative-office.md) | 981fa2e | B forwards reads/writes to A | Alice at A; B relays it |
| [07 Authority outage](07-authority-outage.md) | 981fa2e | B alive, operations unavailable | A restarted, empty |
| [08 Network partition](08-network-partition.md) | 47c24dd | Both alive, B refuses while isolated | Reconnected, Alice retained |
| [09 Desktop forwarding](09-docker-desktop-forwarding.md) | 47c24dd | Diagnose an independent host path failure | Reconnected; optional investigation |
| [10 Modes and record IDs](10-booking-records-and-modes.md) | b2425cb + authority override | Preserve existing behavior with records | Alice record via authority |
| [11 Manual delivery](11-manual-replication.md) | b2425cb + local mode | Duplicate-safe receiver | One Alice record at both |
| [12 Automatic delivery](12-automatic-replication.md) | e4b07a5 + local mode | Background exchange | One converged Alice record |
| [13 Conflict after partition](13-partition-conflict.md) | e4b07a5 + local mode | Independent confirmations, then convergence | Two conflicting records at both |
| [14 Troubleshooting/glossary](14-troubleshooting.md) | Reference | Recover and explain | No required action |

## Why use history instead of running the latest code throughout?

The latest app automatically replicates. The early app does not. Running the latest code during the independent-office or manual-delivery lessons would change the outcome before you understood why. Each lesson therefore names a verified commit and stops the previous stack before switching.

This is a runnable reconstruction of the learning journey, not a collection of unfinished snippets. Complete source already exists at every checkpoint. `git diff` commands connect the implementation changes to each experiment. Application development remains manual; sourcing tutorial helpers only defines command wrappers.

## Evidence policy

Each lesson distinguishes original pasted output, learner-confirmed outcomes without pasted output, and expected replay behavior. New isolated validation is recorded separately in [the validation report](15-validation.md). UUIDs and IPs in historical examples are examples, not constants to hard-code.

Historical source commits:

```text
b5086f18e7090530f3cc1b267a0f0affe8abf22c  single office
0aedb7af54394d9f1dc29ca5dad76b5016ffff02  independent offices
981fa2e9a320f2975124ad865355d3c514ca5988  fixed authority
47c24dd06f21ff9724014de7bf7b0522fea36f3f  separate networks
b2425cbdd6a67f42f10e3384977ab96194ba68fa  modes and receiver
e4b07a5f1c25fb4999cbfc2532656807c2bfd59a  background sender
```

## Maintaining these notes

When adding a new learning: implement, observe the checks, explicitly mark the source commit checkpoint, let the learner commit, then record the verified hash in the note. Do not claim a test was run merely because a command is documented.

For documentation-only improvements, a documentation commit is appropriate; no new application commit is required. README.md and the notes are tracked and shared on GitHub. Stage and commit documentation edits normally; check that any newly created notes are included in the staged changes.

## Kubernetes continuation

The Kubernetes sequence starts with [17 — k3d, Deployment, and Pod replacement](17-k3d-deployment-and-recovery.md). Install the optional [16 — Headlamp dashboard](16-headlamp-dashboard.md) after creating the cluster. File numbers reflect when the notes were added; cluster setup must precede dashboard installation. Both reference source commit 271f190.

Continue with [18 — stable Service discovery across Pod replacement](18-service-discovery.md), source commit 1005f16. This covers only the Ruby application resources.

[19 — two offices with Service-based forwarding](19-two-offices-in-kubernetes.md) records the successful authority-mode experiment at c49c141 and includes the reusable in-cluster client helper.

[20 — authority-mode partition with NetworkPolicy](20-kubernetes-network-partition.md) records the partition and recovery at e267954, including client labels, policy selectors, observed failures, and restoration checks.
