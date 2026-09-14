# 13 — Available decisions, converged records, unresolved conflict

Both isolated offices can confirm a customer. After reconnecting, they agree on two records—but agreement does not fix the double booking.

[All lessons](README.md)

**Source:** `e4b07a5` (same as lesson 12). **No source change.**

**Prediction:** partition empty offices; A confirms Alice, B confirms Bob. Heal; both learn both records and flag conflict. Further delivery must not increase the count.

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

## 1. Verify empty state before isolating

```bash
curl -i http://127.0.0.1:14567/seat
ask_b /seat
```

Require available true and an empty array from both. If Alice from lesson 12 is still present, reset this tutorial stack; that state would make one or both new bookings correctly fail.

## 2. Partition BEFORE either booking

```bash
office_b_id=$(dc ps -q office-b)
docker network disconnect cap-kub-tutorial-coordination "$office_b_id"
curl -i http://127.0.0.1:14567/health
ask_b /health
dc logs --tail=20 office-a office-b
```

Require both health responses 200. Sender logs should show failures after attempts occur. `ask_b` uses access-b; host port 14568 may fail for the already-diagnosed Desktop reason. No container is stopped here.

## 3. Ask each isolated office for the same seat

```bash
curl -i http://127.0.0.1:14567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Alice"}'

ask_b /book '{"customer":"Bob"}'

curl -i http://127.0.0.1:14567/seat
ask_b /seat
```

Require both POSTs 201 with DIFFERENT IDs, office a for Alice and b for Bob. Each read should show its own one record and conflict false. Conflict false means no conflict is known locally; it does not mean no contradictory promise exists elsewhere.

Stop and investigate if either booking is rejected: was state empty, was the partition in place, and is mode local? Reconnect using the next command even when diagnosing an unexpected result.

## 4. Heal without restarting

```bash
docker network connect --alias office-b cap-kub-tutorial-coordination "$office_b_id"
```

Wait for successful delivery cycles, then:

```bash
curl -i http://127.0.0.1:14567/seat
ask_b /seat
```

Require two records on each side, same IDs/contents, available false/conflict true. If convergence does not happen after about 15 seconds, inspect `dc logs --tail=40` and network membership rather than restarting (which erases evidence).

## 5. Verify stability after further cycles

Repeat both reads a few seconds later. Require exactly two records, not three or four. Full-state re-sends do not create new IDs, and the receiver does not duplicate existing IDs.

<details>
<summary>Original evidence</summary>

## Original evidence

A's post-recovery read returned HTTP 200:

```json
{"seat":"A1","available":false,"conflict":true,"bookings":[{"id":"5537aa89-382a-4f9a-a023-05e78719f73d","seat":"A1","customer":"Alice","office":"a"},{"id":"2566528d-b268-41ef-b21a-2755e7bc1d58","seat":"A1","customer":"Bob","office":"b"}]}
```

B returned HTTP 200 with the same records in reverse order. Hash insertion order explains that difference: each office inserted its own confirmation first. Compare sets by ID, not JSON byte-for-byte order.

The learner later confirmed the count stayed two. Partition-time responses were not pasted for the original run; the tutorial's validation report separately records replay checks, rather than inventing historical transcripts.

</details>

## What changed and what did not?

| Property | What we observed |
| --- | --- |
| Local operation availability | Isolated offices can decide from local knowledge |
| Convergence | After delivery resumes, record sets agree |
| Invariant preservation | Broken: two customers were confirmed for one seat |
| Conflict resolution | Not implemented: flagging a conflict does not choose a customer |

Reconciliation of stored records cannot erase promises already returned to customers. A production workflow would need an explicit business resolution policy, or a coordination/ownership design that prevents the conflicting promises in the first place.

This is a teaching demonstration, not a formal proof of every CAP property under arbitrary failures. No persistence, failover, authentication, deletion protocol, or Kubernetes deployment has been implemented.

**End state:** both connected, both contain the conflict. If finished, `dc down --remove-orphans` stops only the tutorial and erases these bookings. No new application commit was needed for this experiment. Review [the glossary and troubleshooting guide](14-troubleshooting.md) before moving to Kubernetes.

---

Next: [17 — Run an office in Kubernetes and observe Pod replacement](17-k3d-deployment-and-recovery.md).
