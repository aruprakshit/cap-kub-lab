# Tutorial validation report

This is the evidence behind the Docker replay instructions. Read it when you want to know what was tested and what those checks do not establish.

[All lessons](README.md)

This report describes actual isolated replay checks, not a guarantee that every machine or future Docker version behaves identically.

<details>
<summary>Environment and isolation</summary>

## Environment and isolation

- Validation date (UTC): 2026-09-13
- Docker Engine: 29.7.2
- Compose: Docker Compose version v5.5.1
- Ubuntu WSL; Ruby runs inside the committed images.
- Project `cap-kub-tutorial`, host ports 14567/14568, coordination network `cap-kub-tutorial-coordination`.
- All six recorded source commits built and their effective Compose configurations were checked for isolated ports/network names.
- Tutorial containers/networks were removed after validation. Original running container IDs remained present. The replay worktree remains available; the original source checkout was not switched.

</details>

## Runtime checks that passed

- 02 single office and restart state loss
- 04 independent double booking
- 06 authoritative forwarding
- 07 authority outage and recovery
- 08 authority partition/client recovery; host during partition: TimeoutError: timed out
- 10 authority mode with booking records
- 11 manual replication duplicate delivery
- 12 asynchronous replication convergence and stable count
- 13 local partition, conflict convergence, stable duplicate count

The host-forwarding observation was a timeout in this isolated run, while the original learner observed a reset. The client path and partition recovery succeeded in both. The tutorial therefore does not require one exact curl failure string or claim all Docker environments reproduce the Desktop issue.

## What these checks do not prove

No concurrent stress test, durable storage test, arbitrary failure proof, Windows-version compatibility matrix, or Kubernetes deployment was performed. Historical forensic logs remain historical evidence. The optional fresh lockfile-generation path is explained but not required or re-run for normal replay; builds used the committed lockfiles.

The validation harness used existing maintainer tooling to drive the same images, helpers, requests, and assertions. Readers do not need that tooling: the executable tutorial requires only Bash, Git, curl, Docker, and Compose. The runnable shell/Markdown checks are reported below once complete.

<details>
<summary>Documentation checks</summary>

## Documentation checks

- 74 Bash blocks passed bash -n; Markdown fences are balanced.
- 50 local links resolve.
- tutorial-shell.sh passed Bash syntax validation.
- The exact documented printf/curl delivery command ran twice at b2425cb: both returned 200 with booking_count 1.
- Syntax checks alone are not treated as runtime verification; runtime scenarios are listed above.

</details>
