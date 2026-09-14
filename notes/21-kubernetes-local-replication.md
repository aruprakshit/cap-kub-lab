# 21 — Local booking and asynchronous replication in Kubernetes

Switch both offices to local mode. B creates Alice’s booking, A learns it through replication, and A then rejects Bob using its own records.

[All lessons](README.md)

## Checkpoint and prerequisites

Source: `6a863177b187d304f292f97eb812b2a60cf25d01` (`6a86317`) — Enable local booking and asynchronous replication in Kubernetes.

Continue after [20 — authority-mode partition](20-kubernetes-network-partition.md). Run in Ubuntu from the original application checkout. Keep the existing k3d-cap-kub-lab cluster, cap-lab namespace, both office Services, imported cap-kub-office:v1 image, and service-client Pod. Reuse the `ask_office` function from [lesson 19](19-two-offices-in-kubernetes.md); that lesson includes client creation and the full helper if you opened a new terminal.

This lesson establishes replication with communication available. Do not apply the partition yet. It is a baseline for the next experiment, not a demonstration of conflict prevention under concurrent requests.

## 1. Restore communication first

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab get networkpolicy
```

Expect the previous experimental policy to be absent. If partition-offices remains, remove it:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  delete -f k8s/partition-offices.yaml
```

Inspect any other policies before continuing; do not delete unrelated policies. Replication needs the offices to reach one another. Establishing normal communication first separates application configuration problems from the deliberate partition we introduce later.

## 2. Connect the configuration to the behavior

At this checkpoint the two Deployment files already contain the changes below. If following the development journey from the previous checkpoint, manually replace each container's env section. Preserve its existing indentation beneath the office container.

Office A, in k8s/office-a.yaml:

```yaml
          env:
            # Mark records created locally by this office.
            - name: OFFICE
              value: a
            # Make local decisions and enable the replication loop.
            - name: COORDINATION_MODE
              value: local
            # Send records through B's existing Service.
            - name: PEER_URL
              value: http://office-b:4567
```

Office B, in k8s/office-b.yaml:

```yaml
          env:
            # Mark records created locally by this office.
            - name: OFFICE
              value: b
            # Stop forwarding booking decisions to A.
            - name: COORDINATION_MODE
              value: local
            # Send records through A's existing Service.
            - name: PEER_URL
              value: http://office-a:4567
```

Remove B's old AUTHORITY_URL entry. Keep one replica for each office. No Service changes are needed: their selectors still match app=office-a and app=office-b, and they still route port 4567 to the named container port http.

| Setting | Application responsibility |
| --- | --- |
| OFFICE | Records which office originally created a booking. |
| COORDINATION_MODE=local | Reads and books using this process's records; enables background replication. |
| PEER_URL | Names the other office's Service as the replication destination. |

Kubernetes supplies these environment variables to Ruby. Ruby implements the booking and replication behavior. The imported image already contains that code, so no rebuild is required.

The application periodically sends a snapshot of its records to the peer's /replicate endpoint. Records retain their IDs and originating office. Receiving the same immutable record again does not create another booking. A successful local booking response does not wait for the peer to store that booking.

## 3. Apply and wait for both replacements

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  apply -f k8s/office-a.yaml -f k8s/office-b.yaml

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  rollout status deployment/office-a --timeout=120s

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  rollout status deployment/office-b --timeout=120s
```

Changing env inside spec.template changes the Pod template and triggers replacement Pods. Wait for both rollouts before booking so you do not test a mixture of old authority-mode and new local-mode processes. Their memory starts empty during this transition from authority mode; there is no database or persistent storage.

Applying identical manifests later does not trigger another replacement and does not reset records. Also, restarting just one local-mode office is not a reliable reset: the surviving peer can send its records back. If replaying on an already populated local-mode lab, stop at the next baseline check and prepare a deliberate reset separately rather than assuming apply empties memory.

## 4. Verify the empty baseline

```bash
ask_office a /seat
ask_office b /seat
```

Both should return HTTP 200:

```json
{"seat":"A1","available":true,"conflict":false,"bookings":[]}
```

If either contains records, do not continue this empty-seat experiment. Check the starting state and rollout history. The original learner observed both empty.

## 5. Book at B

```bash
ask_office b /book '{"customer":"Alice"}'
```

Expect HTTP 201. In the original run:

```json
{"confirmed":true,"booking":{"id":"d9552845-9e32-4db4-b628-205c3d63aaf3","seat":"A1","customer":"Alice","office":"b"}}
```

The office=b field is the key difference from authority mode: B created this booking itself. In the earlier authority experiment, the same client destination produced office=a because A made the decision. Your UUID will differ; record it for the following comparisons.

## 6. Observe replication and then rejection

```bash
ask_office a /seat
```

This first read can be empty or can already contain Alice. A fast successful read does not make replication synchronous: the background sender may have delivered the record before you issued the request.

Wait a few seconds, then check both:

```bash
ask_office a /seat
ask_office b /seat
```

Require the same single booking ID, customer Alice, office=b, and conflict=false at both before continuing. A few seconds is an observation interval, not a guaranteed delivery deadline. If A remains empty, investigate replication rather than booking Bob immediately, which could create a conflict and change this experiment.

Once A knows Alice's booking:

```bash
ask_office a /book '{"customer":"Bob"}'
ask_office a /seat
ask_office b /seat
```

Expect HTTP 409 for Bob and HTTP 200 for both final reads. A rejects Bob using its own replicated records; it does not forward that decision to B.

<details>
<summary>Observed learner results</summary>

## Observed learner results

| Check | Supplied result |
| --- | --- |
| Initial A and B /seat | Both 200, empty records. |
| B books Alice | 201, record originated at B. |
| First A /seat after booking | 200, already contained Alice's record. |
| A books Bob after seeing Alice | 409, Seat already booked. |
| Final A and B /seat | Both 200, same single ID, conflict=false. |

Both final reads contained:

```json
{"seat":"A1","available":false,"conflict":false,"bookings":[{"id":"d9552845-9e32-4db4-b628-205c3d63aaf3","seat":"A1","customer":"Alice","office":"b"}]}
```

The learner did not observe an intermediate empty read at A after booking. Do not invent a visible lag or infer an exact replication duration from this output. These results were supplied by the learner before commit 6a86317; no independent runtime validation is claimed here.

</details>

## Troubleshooting

If requests fail, first inspect the running resources and application logs:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab get pods,services
kubectl --context=k3d-cap-kub-lab -n cap-lab get networkpolicy
kubectl --context=k3d-cap-kub-lab -n cap-lab logs deployment/office-a --tail=40
kubectl --context=k3d-cap-kub-lab -n cap-lab logs deployment/office-b --tail=40
```

- A booking through B still originates at A: verify B's local-mode environment and completed rollout.
- A stays empty while B has Alice: verify both peer URLs, Service endpoints, replication errors, and policy restrictions. Local health alone does not establish replication health.
- Bob receives 201 before A learns Alice: asynchronous replication permits that timing; you have entered the conflicting-booking scenario, not this sequential baseline.
- Records disappear: check container or Pod replacement; data is in memory.

## Conclusion and checkpoint discipline

This experiment shows local decisions plus successful asynchronous delivery over Kubernetes Services. The sequential rejection proves that A used a record it had already received. It does not prove global single-seat safety: both offices can accept different customers before learning the other's decision, even without an intentional partition.

End state: both offices run in local mode, both hold Alice's B-originated record, and the partition policy is absent. Leave that state in place until the next lesson explains how to prepare an empty partitioned experiment.

Implementation was committed at 6a86317. This note follows that verified commit and should be reviewed and committed as documentation. Next we will deliberately isolate the offices, compare their independent decisions, and inspect the records after communication returns.

---

Next: [22 — Available local bookings, then conflict after recovery](22-kubernetes-partition-conflict.md).
