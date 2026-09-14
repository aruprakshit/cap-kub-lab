# 04 — Two correct local decisions can conflict

Two offices can each obey their local booking rule and still sell the same seat twice. Separate containers do not share booking memory or a mutex.

[All lessons](README.md)

**Source:** `0aedb7af54394d9f1dc29ca5dad76b5016ffff02` — Run two independent ticket offices to demonstrate double booking.

**Starting idea:** one process enforced its local booking rule. Predict whether copying the service into another container extends that guarantee across both.

## Prepare the exact source and an empty state

From the tutorial worktree with the [start-here helpers](00-start-here.md) loaded:

```bash
dc down --remove-orphans
git switch --detach 0aedb7a
dc config
dc up -d --build
wait_for_offices
```

Run these in order. Down removes the PREVIOUS tutorial stack and its memory; switching selects the code Docker must copy; config checks the merged YAML; up builds and starts that code; health polling waits for Puma. Confirm no command failed before proceeding. The original checkout is not changed.

## Read what changed

```bash
git diff b5086f1 0aedb7a -- compose.yml
```

The single service `office` became `office-a` and `office-b`. The app code is the same. An image is a filesystem/runtime template, not shared Ruby memory. Each container gets its own BOOKINGS predecessor (`BOOKING`) and mutex.

The tutorial exposes A on 14567, B on 14568, both internally on 4567. Verify the empty baseline:

```bash
curl -i http://127.0.0.1:14567/seat
curl -i http://127.0.0.1:14568/seat
```

Require available true on both.

## Sell through A, then through B

```bash
curl -i http://127.0.0.1:14567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Alice"}'

curl -i http://127.0.0.1:14568/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Bob"}'
```

Expect 201 from BOTH. Alice's operation can finish before Bob's starts; simultaneous requests are not necessary because there is no communication at all.

```bash
curl -i http://127.0.0.1:14567/seat
curl -i http://127.0.0.1:14568/seat
```

A: `{"seat":"A1","available":false,"customer":"Alice"}`.

B: `{"seat":"A1","available":false,"customer":"Bob"}`.

## Connect the dots

These exact response bodies and statuses were pasted in the original experiment. Each office prevented a second local booking, but they confirmed the SAME seat to two customers. Neither local mutex reached the other process.

This is not a partition experiment yet: there is no replication/coordination link to break. Waiting longer will never make the offices agree. Nor does a successful health check imply shared data.

**End state:** two running offices with conflicting local customers. Do not overwrite one record to hide the problem. The next implementation makes A authoritative; lesson 06 starts it from a clean state. [Lesson 05](05-docker-commands.md) is a reference page, not a script to execute top-to-bottom.

---

Next: [06 — Two entry points, one authority](06-authoritative-office.md).
