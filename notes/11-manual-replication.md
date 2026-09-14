# 11 — Deliver records manually and safely repeat delivery

Send Alice’s record to B yourself, then send the identical record again. B should retain one record and use it to reject Bob.

[All lessons](README.md)

**Source:** `b2425cbdd6a67f42f10e3384977ab96194ba68fa` (same source as lesson 10). Now select LOCAL mode. Automatic sending does not exist yet.

**Prediction:** Alice is known only to A until delivered; identical repeated delivery adds one record at B, not two; B then rejects Bob.

## Start clean at the required checkpoint

From the tutorial worktree with [helpers loaded](00-start-here.md):

```bash
dc down --remove-orphans
git switch --detach b2425cb
export TUTORIAL_MODE=local
dc config
dc up -d --build
wait_for_offices
```

Down intentionally discards earlier bookings. Switch selects the required implementation before the build. Wait for health before issuing business requests. Do not continue if an earlier command failed.

## Read the receiver's rules

`POST /replicate` requires local mode, an array of records, nonempty string IDs/customer names, seat A1, and office a/b. JSON is parsed with symbol keys to match locally generated Ruby records. The whole batch is validated before insertion.

```ruby
BOOKINGS[record[:id]] ||= {
  id: record[:id], seat: record[:seat],
  customer: record[:customer], office: record[:office]
}
```

The merge holds the mutex. An existing ID is left alone. This is idempotent DELIVERY of the same record; it does not make repeated POST /book calls idempotent.

Assumption: an ID identifies one immutable record. The implementation does not reject different contents under the same ID; it keeps the first. Do not claim general conflict resolution or exactly-once processing.

## 1. Create a decision at A, then show B is unaware

```bash
curl -i http://127.0.0.1:14567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Alice"}'

curl -i http://127.0.0.1:14568/seat
```

Require 201 at A with a new booking ID, then 200 at B with an EMPTY array and available true. Waits do not change B at this version: nobody sends records automatically.

## 2. Copy the decision's ID, not a prior lesson's ID

Enter the UUID from A's response between the quotes:

```bash
alice_id='REPLACE_WITH_THE_ID_JUST_RETURNED_BY_A'
```

Do not run the next command with the placeholder unchanged. The ID must match the actual decision you are transferring. Then deliver that record to B:

```bash
replication_body=$(printf '[{"id":"%s","seat":"A1","customer":"Alice","office":"a"}]' "$alice_id")

curl -i http://127.0.0.1:14568/replicate \
  -H 'Content-Type: application/json' \
  -d "$replication_body"
```

The single-quoted printf format preserves JSON quotes; `%s` inserts the UUID. Quoting `$replication_body` passes the whole JSON array as one argument. This is suitable for the generated UUID here, not a general JSON encoder for arbitrary text.

Require HTTP 200 and `{"office":"b","booking_count":1,"conflict":false}`. We manually simulated peer delivery; we have not tested an office-to-office sender.

## 3. Repeat the exact same curl command

Run step 2's delivery again WITHOUT generating a new ID. Require booking_count still 1. Retrying a transmission should not invent another confirmation.

## 4. Make a decision using received knowledge

```bash
curl -i http://127.0.0.1:14568/seat

curl -i http://127.0.0.1:14568/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Bob"}'
```

Require one Alice record at B and Bob rejected with 409. B is deciding locally from a record it received, not forwarding this booking to A.

Why does replication not reject a record when occupied? It records a confirmation ALREADY made elsewhere. Rejecting that evidence would conceal the conflict. Lesson 13 exercises multiple distinct records; this lesson exercises repeated identical delivery.

## Evidence and finish

The learner confirmed all predicted outcomes; raw output was not pasted for that original run. This does not yet establish eventual convergence because automatic exchange is absent. The later validation report separately states which tutorial checks were executed.

**End state:** both have Alice. Source checkpoint was committed as b2425cb only after successful checks. [Lesson 12](12-automatic-replication.md) changes the sender implementation and starts fresh.

---

Next: [12 — Replicate automatically without blocking local requests](12-automatic-replication.md).
