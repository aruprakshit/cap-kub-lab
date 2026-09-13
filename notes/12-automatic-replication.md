# 12 — Replicate automatically without blocking local requests

**Source:** `e4b07a5f1c25fb4999cbfc2532656807c2bfd59a` — Add periodic asynchronous replication between ticket offices.

**Prediction:** Alice booked at A appears at B without manual delivery; repeated cycles retain one record. Only try Bob AFTER B has learned Alice.

## Start clean at the required checkpoint

From the tutorial worktree with [helpers loaded](00-start-here.md):

```bash
dc down --remove-orphans
git switch --detach e4b07a5
export TUTORIAL_MODE=local
dc config
dc up -d --build
wait_for_offices
```

Down intentionally discards earlier bookings. Switch selects the required implementation before the build. Wait for health before issuing business requests. Do not continue if an earlier command failed.

## Read what changed

```bash
git diff b2425cb e4b07a5 -- app.rb compose.yml
```

PEER_URL points to the other office. A background thread in local mode sleeps two seconds, snapshots all records under the mutex, releases it, then POSTs to the peer's receiver. Both offices do this. Caught network errors are logged and the next cycle tries again.

Why not hold the lock during the HTTP request? That would make local booking/read requests wait behind an unreachable peer, undermining the availability we want to examine. A booking after a snapshot waits for the next cycle, not for the current send.

Why resend all records? It is simple anti-entropy for this tiny dataset: each successful delivery can repair missed earlier deliveries. The receiver's ID-based merge handles duplicates. This is not an efficient design for an unbounded database.

Two seconds is the sleep, not the entire cycle. Connection and read time add time. Unexpected exceptions can terminate this unsupervised thread; successful delivery is not durable persistence. The implementation assumes the current single-process Puma deployment.

## 1. Book Alice

```bash
curl -i http://127.0.0.1:14567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Alice"}'
```

Require 201. Record the UUID. The local response does not wait for peer acknowledgement.

## 2. Observe propagation, not a fixed deadline

```bash
curl -i http://127.0.0.1:14568/seat
```

An immediate read may be empty. Repeat after a few seconds until B shows Alice with the SAME ID and office a. If it has not appeared after about 15 seconds on this healthy local lab, stop and inspect `dc logs --tail=40 office-a office-b`; do not blindly continue. Fifteen seconds is a troubleshooting threshold, not a protocol guarantee.

## 3. Reject Bob using the learned record

```bash
curl -i http://127.0.0.1:14568/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Bob"}'
```

Require 409. If Bob was accepted, first check whether B had actually learned Alice before step 3. Concurrent independent decisions are possible even on a healthy but delayed network; that would not disprove the code's asynchronous nature.

## 4. Confirm duplicate-safe convergence

After several more cycles:

```bash
curl -i http://127.0.0.1:14567/seat
curl -i http://127.0.0.1:14568/seat
dc logs --tail=20 office-a office-b
```

Both must retain exactly one record with the same ID, available false/conflict false. Sender log lines alone are not sufficient evidence: read the receiver state too.

Original pasted response from BOTH offices (UUID changes on replay):

```json
{"seat":"A1","available":false,"conflict":false,"bookings":[{"id":"329ed577-864a-4e7f-a8d7-35576184bed4","seat":"A1","customer":"Alice","office":"a"}]}
```

The learner also confirmed the other predicted checks. The original 201/409 were not pasted in that checkpoint; the final matching reads were.

**End state:** both connected, Alice known everywhere. This does not prove at-most-one booking under all timings. [Lesson 13](13-partition-conflict.md) resets FIRST, then partitions BEFORE booking, so both offices start isolated and empty.
