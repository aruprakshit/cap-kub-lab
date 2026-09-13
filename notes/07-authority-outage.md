# 07 — Process health is not operation availability

**Source:** `981fa2e` (same as lesson 06). **No code change.**

**Start:** finish [lesson 06](06-authoritative-office.md) with both offices running and Alice booked at A. If joining here, run that lesson first; do not assume an old container has the correct code or state.

**Prediction:** stopping A leaves B alive but unable to answer authoritative reads or bookings.

## Stop only the dependency

```bash
dc stop office-a
dc ps -a
```

A should be stopped while B stays running. `stop` preserves the container but ends its Ruby process. Do not use down here: that would stop B as well and erase the distinction we are testing.

## Test liveness, read, and write separately

```bash
curl -i http://127.0.0.1:14568/health
```

Require 200 with `{"status":"ok"}`. This endpoint needs no authority.

```bash
curl -i http://127.0.0.1:14568/seat

curl -i http://127.0.0.1:14568/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Bob"}'
```

Require 503 from both, with the original implementation's body:

```json
{"error":"Cannot reach authority","office":"b","detail":"A booking may have completed before communication failed."}
```

All three outputs were pasted in the original experiment. An HTTP error response is not successful completion of the requested booking/read. B does not fall back to its empty local state.

## Understand the error message's limitation

The shared detail is overly broad for GET: a read does not create a booking. For POST in general, a lost response can leave the caller uncertain whether A accepted a booking. Here we deliberately stopped A first, so Bob's request could not be processed by it. We preserve this known wording flaw in the historical source, rather than silently claiming it was fixed.

## Recover and check what recovery does NOT preserve

```bash
dc start office-a
wait_for_offices
curl -i http://127.0.0.1:14568/seat
```

Expect an empty seat. A starts a new process, so Alice's in-memory booking is gone. This explicit recovery check is tutorial replay guidance; the original outage transcript ended with A stopped.

**Conclusion:** we tested an authority outage, not a partition between running offices. Next, [lesson 08](08-network-partition.md) changes the network configuration and isolates communication without stopping processes.
