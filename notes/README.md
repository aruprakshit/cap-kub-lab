# Lab notes

There are two ways to use these notes. Read the opening paragraph of each lesson to follow the idea, or work through the steps to see it happen locally. Longer historical output is tucked into expandable sections where it would otherwise interrupt the experiment.

For a first run, begin with [setup](00-start-here.md). Keep the preparation and recovery steps: they establish the state the next experiment depends on.

## Start with Docker

1. [Set up the replay worktree](00-start-here.md)
2. [Put Ruby and its dependencies in a container](01-container-setup.md)
3. [Book one seat at one office](02-one-office.md)
4. [Understand what the mutex protects](03-mutex-and-snapshots.md)
5. [Watch two independent offices double-book](04-two-offices.md)
6. [Make A the booking authority](06-authoritative-office.md)
7. [Stop A and check what B can still do](07-authority-outage.md)
8. [Break communication without stopping the offices](08-network-partition.md)
9. [Give bookings IDs and introduce modes](10-booking-records-and-modes.md)
10. [Deliver a record manually, twice](11-manual-replication.md)
11. [Let replication run in the background](12-automatic-replication.md)
12. [Reconnect offices that made conflicting promises](13-partition-conflict.md)

## Repeat it in Kubernetes

Use the original checkout for this part. The Kubernetes setup explains how to create the cluster and import the image; the Docker replay worktree is for the earlier experiments.

1. [Run an office and replace its Pod](17-k3d-deployment-and-recovery.md)
2. [Keep a stable address with a Service](18-service-discovery.md)
3. [Connect B to A through Services](19-two-offices-in-kubernetes.md)
4. [Block coordination with NetworkPolicy](20-kubernetes-network-partition.md)
5. [Enable local decisions and replication](21-kubernetes-local-replication.md)
6. [Observe a conflict after recovery](22-kubernetes-partition-conflict.md)
7. [Build a reusable client command](23-declarative-client-utility.md)

## Look these up when needed

- [Docker commands and original build history](05-docker-commands.md)
- [The Docker Desktop forwarding investigation](09-docker-desktop-forwarding.md)
- [Troubleshooting and glossary](14-troubleshooting.md)
- [Docker replay validation results](15-validation.md)
- [Optional dashboard setup](16-headlamp-dashboard.md) — after creating the cluster

<details>
<summary>Why the lessons name different Git commits</summary>

The app changes as the experiments progress. Early offices do not replicate; later ones do. Each lesson names the source version that produces its intended behavior, so use its checkpoint rather than the latest code throughout. File numbers also reflect when notes were added; follow the order above.

Each lesson distinguishes supplied results from expected replay behavior. The validation report records the separate Docker replay checks. Example UUIDs and IP addresses are observations, not values to hard-code.

</details>

<details>
<summary>Adding a new lesson</summary>

Implement a small change, run its checks, commit the implementation, then write the note against that hash. Record only the results actually observed; keep unrun checks labelled as expectations. Replaying an existing checkpoint does not require a new implementation commit.

Keep the main point near the top. Leave required setup, commands, expected outcomes, and recovery visible. Use expandable sections for lengthy transcripts and optional background. Commit documentation after review, and make sure new notes appear in the staged changes.

</details>
