# 06 — Two entry points, one authority

B now asks A to make the decision. Booking through either office consults the same authority, so Bob is rejected after Alice succeeds.

[All lessons](README.md)

**Source:** `981fa2e9a320f2975124ad865355d3c514ca5988` — Route bookings and reads through office A as the fixed authority.

**Prediction:** a booking through B and a later booking through A consult the same state, so Alice succeeds and Bob is rejected.

## Prepare the exact source and an empty state

From the tutorial worktree with the [start-here helpers](00-start-here.md) loaded:

```bash
dc down --remove-orphans
git switch --detach 981fa2e
dc config
dc up -d --build
wait_for_offices
```

Run these in order. Down removes the PREVIOUS tutorial stack and its memory; switching selects the code Docker must copy; config checks the merged YAML; up builds and starts that code; health polling waits for Puma. Confirm no command failed before proceeding. The original checkout is not changed.

## Read the implementation change before testing

```bash
git diff 0aedb7a 981fa2e -- app.rb compose.yml
```

B forwards `/seat` and `/book` to `http://office-a:4567`. A handles them locally. `/health` stays local in both processes. The helper uses Net::HTTP, relays A's response, and `halt`s so B does not continue into its own local booking code.

```text
Client -> A -> A's state
Client -> B -> A -> A's state
```

A Compose service name is resolvable on their shared network. `localhost` inside B would mean B itself. AUTHORITY_URL is a container-network URL, not the host port 14567.

The one-second connection timeout and two-second read timeout limit phases of a peer call; they are not a strict total request deadline. Caught connection failures return 503.

## A failure we encountered: Host not permitted

The original first forward returned 403 before the booking route. Sinatra did not accept Host `office-a:4567`. This commit already contains the fix:

```ruby
set :host_authorization, {
  permitted_hosts: ["localhost", "127.0.0.1", "office-a", "office-b"]
}
```

Do not add a duplicate setting during replay. Host authorization validates the HTTP hostname; bind controls the listening interface; the Compose port controls host exposure. These solve different problems. If you see the 403 now, confirm HEAD and rebuild rather than disabling all host checks.

## Book through B; challenge through A

```bash
curl -i http://127.0.0.1:14568/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Alice"}'

curl -i http://127.0.0.1:14567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Bob"}'
```

Require Alice 201 and Bob 409, referencing Alice. Then:

```bash
curl -i http://127.0.0.1:14567/seat
curl -i http://127.0.0.1:14568/seat
```

Both must return 200 and `{"seat":"A1","available":false,"customer":"Alice"}`. These outcomes were all pasted in the original run.

**Meaning:** B has no synchronized replica; a successful B read is an A read relayed back. We traded independent decisions for a dependency on A. A remains fixed, with volatile state and no failover.

**End state:** both running, Alice at A. Do NOT reset before [lesson 07](07-authority-outage.md), which deliberately stops A and observes the consequence.

---

Next: [07 — Process health is not operation availability](07-authority-outage.md).
