# 02 — One office accepts one booking

**Source:** `b5086f18e7090530f3cc1b267a0f0affe8abf22c` — Add containerized Sinatra ticket booking service with Bundler and Docker Compose.

**Question:** can one process enforce one confirmed customer for A1? Predict the first booking succeeds and the next is rejected.

## Prepare the exact source and an empty state

From the tutorial worktree with the [start-here helpers](00-start-here.md) loaded:

```bash
dc down --remove-orphans
git switch --detach b5086f1
dc config
dc up -d --build
wait_for_offices
```

Run these in order. Down removes the PREVIOUS tutorial stack and its memory; switching selects the code Docker must copy; config checks the merged YAML; up builds and starts that code; health polling waits for Puma. Confirm no command failed before proceeding. The original checkout is not changed.

## 1. Read before writing

```bash
curl -i http://127.0.0.1:14567/seat
```

Require HTTP 200 with `{"seat":"A1","available":true,"customer":null}`. This proves our starting state is empty. If already occupied, you did not reset this stack or are calling the wrong port; do not proceed with an already-booked seat.

## 2. Book Alice

```bash
curl -i http://127.0.0.1:14567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Alice"}'
```

Expect HTTP 201 with `{"seat":"A1","customer":"Alice","confirmed":true}`. A response confirming a booking is a promise to a customer, not just a value in memory.

## 3. Read after the completed booking

```bash
curl -i http://127.0.0.1:14567/seat
```

Expect 200, available false, customer Alice. This read begins after the booking completed, so it should reflect that decision in this single office.

## 4. Try a second customer

```bash
curl -i http://127.0.0.1:14567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Bob"}'
```

Expect 409 and `{"error":"Seat already booked","customer":"Alice"}`. Returning 409 is the correct application result here. Repeating Alice's POST also returns 409: the endpoint has no idempotency key or replayed-success behavior.

## 5. Observe volatile state explicitly

Only AFTER recording the earlier results:

```bash
dc restart office
wait_for_offices
curl -i http://127.0.0.1:14567/seat
```

Expect an empty seat again. Restart starts a new Ruby process; there is no database or persistent volume. Restart does not rebuild source. This is why later partition experiments must not restart during isolation/recovery.

## Evidence and conclusion

The original run pasted the initial 200, Alice 201, booked read, and Bob 409. It also showed empty state again without a pasted intervening restart. The explicit reset test above is clarified replay guidance. Sequential requests establish the expected behavior; they are not a concurrent stress test.

**End state:** one running office, empty after step 5. Keep it running while reading [lesson 03](03-mutex-and-snapshots.md). No new source commit is needed to replay an existing checkpoint.
