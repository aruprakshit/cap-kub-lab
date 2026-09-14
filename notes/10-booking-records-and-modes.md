# 10 — Select a strategy and preserve booking identities

Give each booking an ID before exchanging records. First check that the new representation still behaves correctly in authority mode.

[All lessons](README.md)

**Source:** `b2425cbdd6a67f42f10e3384977ab96194ba68fa` — Add local booking mode and idempotent replication receiver.

This commit bundles the record representation and receiver. The committed mode is local; this lesson intentionally overrides it to authority to check that the representation change preserves the earlier behavior.

## Prepare the exact source and an empty state

From the tutorial worktree with the [start-here helpers](00-start-here.md) loaded:

```bash
dc down --remove-orphans
git switch --detach b2425cb
export TUTORIAL_MODE=authority
dc config
dc up -d --build
wait_for_offices
```

Run these in order. Down removes the PREVIOUS tutorial stack and its memory; switching selects the code Docker must copy; config checks the merged YAML; up builds and starts that code; health polling waits for Puma. Confirm no command failed before proceeding. The original checkout is not changed.

## Read the change

```bash
git diff 47c24dd b2425cb -- app.rb compose.yml
```

COORDINATION_MODE selects a strategy, not an office identity:

| OFFICE | COORDINATION_MODE | Decision path |
| --- | --- | --- |
| a | authority | Local authority |
| b | authority | Forward to A |
| a or b | local | Local decision |

Both processes receive their own environment settings. Setting authority on A is currently explicit configuration, not a change in its behavior. It defaults to authority; an unknown mode aborts startup.

The tutorial mode overlay supplies `TUTORIAL_MODE` to both services, so source files remain clean for the next Git switch. Verify the effective environment using `dc config` rather than assuming an exported shell variable automatically enters a container.

## Why records instead of one customer field?

A single overwritten value can hide a previous confirmation. BOOKINGS now maps IDs to records containing id, seat, customer, and office. SecureRandom.uuid supplies an identity, and `office` records who made the decision. No extra gem is needed.

The write mutex still covers the check plus insert. GET copies the records under the lock (`map(&:dup)`) and formats afterward. These are shallow copies; nested strings are not modified in place by this code.

## Verify authority behavior with the new format

```bash
curl -i http://127.0.0.1:14568/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Alice"}'

curl -i http://127.0.0.1:14567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Bob"}'

curl -i http://127.0.0.1:14568/seat
```

Require Alice 201 with a new ID and office a (even though the request entered B), Bob 409, and a read containing exactly one Alice record with available false/conflict false.

Original observed read (your UUID differs):

```json
{"seat":"A1","available":false,"conflict":false,"bookings":[{"id":"a60a6f22-f494-4dad-b08c-53ec71492e4c","seat":"A1","customer":"Alice","office":"a"}]}
```

All original responses were pasted and matched those checks. The new array is preparation for conflicts, not evidence of replication yet.

**End state:** authority mode, one record at A. [Lesson 11](11-manual-replication.md) explicitly resets state and selects local mode. Do not merely export local without recreating containers: running process environments would remain unchanged.

---

Next: [11 — Deliver records manually and safely repeat delivery](11-manual-replication.md).
