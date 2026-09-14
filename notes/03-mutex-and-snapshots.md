# 03 — A mutex protects one process

A mutex coordinates threads inside one Ruby process. Locking a read also matters when the response must describe one coherent state; a second process has its own lock.

[All lessons](README.md)

Start after [lesson 02](02-one-office.md), at `b5086f1`, with its tutorial stack unchanged. This is a code-reading lesson, not an additional executed concurrency experiment. Run `cat app.rb` in the tutorial worktree to connect these explanations with the complete implementation. No reset or new source commit is needed here.

## Why lock POST?

Puma can handle requests on multiple threads. Without coordination, this interleaving is possible:

| Step | Alice | Bob |
| --- | --- | --- |
| 1 | Reads seat as empty | |
| 2 | | Reads seat as empty |
| 3 | Stores Alice and confirms | |
| 4 | | Stores Bob and confirms |

The final stored value may name only Bob, but both customers received confirmation. Protecting just the assignment would not protect the earlier decision.

```ruby
BOOKING_LOCK.synchronize do
  # Check availability, record a booking, and construct the result.
end
```

Only one thread at a time enters a block protected by this particular mutex. The check and update happen together relative to other code using the same mutex. The lock is released when the block exits, including when an exception unwinds it.

## Why lock GET?

An earlier GET implementation read the shared customer twice:

```ruby
available: BOOKING[:customer].nil?,
customer: BOOKING[:customer]
```

A writer could run between the reads. GET could then produce the contradictory pair `available: true` and `customer: "Alice"`.

The current code captures one value under the shared mutex:

```ruby
customer = BOOKING_LOCK.synchronize { BOOKING[:customer] }

{
  seat: "A1",
  available: customer.nil?,
  customer: customer
}.to_json
```

Both response fields derive from that captured value. JSON formatting does not need to keep the lock. This is valid for our code because we replace the stored customer and do not mutate the captured string in place.

A booking may happen after GET captures its value. Returning that earlier snapshot is not a contradictory response: GET and the booking overlapped. The aim is a coherent snapshot, not a promise that the world cannot change before the response reaches the client.

## Boundary of the guarantee

The mutex only coordinates threads sharing that mutex in one Ruby process. It does not coordinate different Puma worker processes, containers, or machines.

```text
Office A process: BOOKING A + mutex A
Office B process: BOOKING B + mutex B
```

The rule is not that every GET needs a lock. Shared mutable state needs appropriate coordination when a consistent view matters.

Next: [two independent offices](04-two-offices.md).

---

Next: [04 — Two correct local decisions can conflict](04-two-offices.md).
