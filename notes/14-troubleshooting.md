# Troubleshooting, recovery, and glossary

## First identify which layer failed

| Symptom | Check first | Why |
| --- | --- | --- |
| `dc: command not found` | Enter Bash, set both tutorial paths, source tutorial-shell.sh | Shell functions are not permanent commands |
| Wrapper says wrong directory | `cd "$TUTORIAL_WORK"` | Prevents targeting a different checkout accidentally |
| Unsupported checkpoint | `git log -1 --oneline` | Each lesson requires a particular historical version |
| Missing commit | `git cat-file -t HASH` and fetch history | A shallow clone may omit lesson versions |
| Worktree directory exists | `git -C "$TUTORIAL_SOURCE" worktree list` | Reuse the correct existing checkout, never overwrite unrelated files |
| Git switch refuses | `git status --short`, `git diff` | Preserve local edits rather than forcing a reset |
| YAML error | `dc config`, indentation in the referenced file | A failed config means no successful recreation happened |
| `!override` unsupported | `docker compose version` | The tutorial requires Compose 2.24.4+ merge support |
| Port already allocated | `docker ps --format 'table {{.Names}}\t{{.Ports}}'` | Another service owns tutorial port 14567 or 14568; identify it before stopping anything |
| Connection refused right after startup | `wait_for_offices`, then `dc logs --tail=40` | Container creation can precede Puma readiness |
| 403 Host not permitted | Check source version and Host name | The authority commit includes permitted Compose service aliases |
| Expected 201, got 409 | Read /seat | The seat is already known as occupied; reset only if the lesson says to start empty |
| Expected empty B, got Alice immediately | Check HEAD and mode | Automatic replication exists at e4b07a5, not at b2425cb |
| Expected 503, got a local 200 | `dc config` environment | You may be in local mode during the authority experiment |
| Invalid JSON 400 | Shell quoting and body shape | /book expects an object; /replicate expects an array |
| Local change has no effect | `dc up -d --build` | COPY source is in the image; restart alone reuses it |
| B host request resets/timeouts after detach | `ask_b /health`, inspect logs | Known Desktop path issue; see lesson 09 |
| Replication never converges | Check both mode/peer URLs, network membership, then logs | Neither a healthy process nor a sender log alone proves delivery |

## Resume a partition without losing evidence

From the tutorial worktree with helpers loaded:

```bash
office_b_id=$(dc ps -q office-b)
docker inspect "$office_b_id" --format '{{json .NetworkSettings.Networks}}'
```

If coordination is absent, restore it:

```bash
docker network connect --alias office-b cap-kub-tutorial-coordination "$office_b_id"
```

If Docker says it is already connected, do not keep reconnecting or force-disconnecting; inspect its actual state and test the endpoint. Reconnection preserves memory. Restarting does not.

## Reset only when a fresh experiment requires it

```bash
dc down --remove-orphans
dc up -d --build
wait_for_offices
```

This is deliberately destructive to tutorial bookings. It is safe for a fresh baseline but invalidates a claim about preserving data across a partition. It does not clear other Compose projects. Do not use global `docker system prune`, delete Docker's network database, reinstall Docker, or disable firewalls merely because a tutorial check failed.

## Reading responses

| Result | Meaning in this application |
| --- | --- |
| 200 /health | This process answers a local liveness request |
| 200 /seat | A read succeeded through that request path |
| 201 /book | This office/authority confirmed a booking |
| 409 /book | The seat is already known as occupied |
| 409 /replicate | Replication attempted in authority mode |
| 400 | Request JSON or fields are invalid |
| 503 | Required authoritative operation cannot be served |
| curl connection error | No complete HTTP response; different from application 503 |

A business rejection can be a valid completed operation. A 503 caused by inability to contact the authority does not provide the requested successful read/booking semantics. Do not equate any HTTP response with CAP availability.

## Concepts that must stay separate

- **Mutex:** mutual exclusion among threads sharing the same mutex, not among separate processes.
- **Authority:** the fixed process permitted to make decisions in authority mode.
- **Forwarding:** B asks A; it does not keep an independently readable synchronized replica.
- **Replication:** transfer of records so another process has its own local copy.
- **Asynchronous:** local confirmation does not wait for the peer to learn the record.
- **Idempotent delivery:** re-delivering the identical record ID/content does not duplicate it. It does not make /book exactly-once.
- **Partition:** communication between participants fails while participants may remain running. This lab removes a Docker network endpoint, including shared-network discovery.
- **Convergence:** replicas eventually agree on record contents when delivery succeeds. It does not imply every earlier read was current.
- **Conflict detection:** more than one confirmation for one seat is exposed.
- **Conflict resolution:** a business/protocol decision about what to do with those confirmations; not implemented.
- **Durability:** survival across relevant failures. Ruby memory is not durable storage.
- **Linearizability:** operations behave as if on one object in an order respecting completed-before-started relationships. Agreement in one final screenshot alone does not prove it.

CAP concerns consistency and availability during communication partitions. The fixed-authority refusal and local-acceptance conflict illustrate the tradeoff; the toy system is not a complete proof or production consensus protocol. Distinguish this use of consistency from ACID's invariant-related terminology.

## Known limits retained in historical source

The GET 503 mentions a possibly completed booking even though GET cannot create one. The replication receiver trusts immutable IDs and ignores mismatched contents for existing IDs. Data is volatile. The sender is an unsupervised thread and sends full state. Host port behavior depends on Desktop networking. These are explicit teaching limits, not claims that those areas were production-hardened.

## Checkpoint questions before Kubernetes

1. Why does B return 503 in authority mode but accept a booking in local mode when isolated?
2. Why does B's health check remain 200 in both cases?
3. Why must partition tests start empty before the two bookings?
4. Why is the network call outside BOOKING_LOCK?
5. How can both replicas agree and still have violated the seat rule?
6. Why does restarting during recovery invalidate our state-preservation observation?
7. Why did the client container reach B while a host published port failed?

If you can explain these using the observed requests and records, the next step is moving the same application to Kubernetes without assuming Kubernetes supplies its consistency protocol.
