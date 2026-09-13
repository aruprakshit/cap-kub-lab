# 08 — Isolate B while both offices remain running

**Source:** `47c24dd06f21ff9724014de7bf7b0522fea36f3f` — Separate office access and coordination networks for partition testing. Application still uses a fixed authority.

**Prediction:** B's health remains 200, but reads and bookings return 503; A still serves Alice. Reconnecting restores B without erasing Alice.

## Start clean at the required checkpoint

From the tutorial worktree with [helpers loaded](00-start-here.md):

```bash
dc down --remove-orphans
git switch --detach 47c24dd
dc config
dc up -d --build
wait_for_offices
```

Down intentionally discards earlier bookings. Switch selects the required implementation before the build. Wait for health before issuing business requests. Do not continue if an earlier command failed.

## Understand the two paths before breaking either

```text
Host port 14567 -------- A
                         |
                    coordination
                         |
Temporary client -- access-b -- B
```

Read the topology and effective override:

```bash
cat compose.yml
dc config
```

A and B each have an access network and share coordination. The overlay renames coordination to `cap-kub-tutorial-coordination`. Container service names and internal port 4567 do not change.

We deliberately reach B from a client on access-b. In the original Desktop environment, disconnecting coordination broke B's host-port forwarder even though access-b still worked. [Lesson 09](09-docker-desktop-forwarding.md) contains the diagnosis. This client is an explicit independent test path, not a claim that the Desktop problem is fixed.

## Read the client helper

```bash
declare -f ask_b
```

It finds B's running container using `dc ps -q office-b`, inspects its image ID, and runs a temporary container from the SAME image on `cap-kub-tutorial_access-b`. Ruby's HTTP client calls `office-b:4567`. An optional second argument supplies JSON and selects POST; otherwise it sends GET. It prints HTTP status/body. `--rm` removes only the temporary client afterward.

No new runtime is installed. It resolves B by the alias on access-b, so removing coordination does not remove this client path. The helper is not available in earlier checkpoints without access-b.

## 1. Establish a working authoritative booking

```bash
ask_b /health
ask_b /book '{"customer":"Alice"}'
ask_b /seat
```

Require 200 health, 201 booking, and 200 showing Alice. A made the decision even though B was the entry point.

## 2. Remove only B's coordination endpoint

```bash
office_b_id=$(dc ps -q office-b)
printf '%s\n' "$office_b_id"
docker network disconnect cap-kub-tutorial-coordination "$office_b_id"
```

The printed ID must be nonempty. `disconnect` removes network membership from a running container; it does not stop Ruby. It also removes B's access to service discovery on that shared network, so this is loss of communication, not a narrowly controlled packet-loss test.

## 3. Verify the intended failure boundary

```bash
ask_b /health
ask_b /seat
ask_b /book '{"customer":"Bob"}'
curl -i http://127.0.0.1:14567/seat
```

| Check | Required result | Why |
| --- | --- | --- |
| B health | 200, status ok | Client still reaches B |
| B seat | 503 | No reachable authority |
| B book | 503 | B cannot decide independently |
| A seat | 200, Alice | A's side remains operational |

The exact historical 503 body is:

```json
{"error":"Cannot reach authority","office":"b","detail":"A booking may have completed before communication failed."}
```

The write-uncertainty wording is overbroad for GET; lesson 07 explains why. If B health fails at the client path, stop interpreting this run as the desired partition.

## 4. Always heal without restarting

```bash
docker network connect --alias office-b cap-kub-tutorial-coordination "$office_b_id"
ask_b /seat
```

Require 200 and Alice. Reconnect even if step 3 did not match expectations. If the shell was closed, reload helpers and recapture the ID; do not restart containers just to restore a variable.

## Observed learning

The original learner supplied all predicted results, including Alice after reconnection. This demonstrates refusal of authoritative operations on the isolated side. Successful reads from A alone do not make operations available to clients isolated at B. B had no independent writes to reconcile: it resumed asking A.

**End state:** both connected, Alice retained. Leave running for the optional forensic replay in [lesson 09](09-docker-desktop-forwarding.md). This is a teaching example with no durable storage or failover, not a proof that every possible history satisfies a production consistency guarantee.
