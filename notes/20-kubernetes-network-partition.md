# 20 — Partition the offices with Kubernetes NetworkPolicy

Keep client access open while NetworkPolicy blocks office-to-office traffic. B stays ready but cannot complete authority-dependent operations.

[All lessons](README.md)

## Checkpoint and purpose

Source checkpoint: `e267954e5eb6dc1ff694e4446444fde43692624a` (`e267954`) — Demonstrate authority-mode partition behavior with NetworkPolicy.

Continue from [19 — two offices in Kubernetes](19-two-offices-in-kubernetes.md). Run commands in Ubuntu, from the original `cap-kub-lab` checkout. This lesson uses the existing cluster, not the separate Docker tutorial worktree or its `dc` wrapper.

Both offices run in authority mode. B forwards booking reads and writes to A. We will block communication between the offices while preserving client access, then remove that restriction. The prediction: A continues serving; B refuses booking operations rather than making an independent decision.

The manifest exists at the source checkpoint. Readers replaying history can inspect it with:

```bash
git show e267954:k8s/partition-offices.yaml
```

Do not switch revisions with unfinished work. Follow the earlier Kubernetes lessons to establish the running resources before this experiment. No image rebuild, package installation, or Deployment change is needed.

## 1. Establish the baseline

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab get pods
kubectl --context=k3d-cap-kub-lab -n cap-lab get networkpolicy
```

Require office-a, office-b, and service-client to be Ready. Expect no existing NetworkPolicies for this replay. If policies exist, inspect them first: permissions from policies are additive, and another policy can allow traffic this experiment intends to block. Do not delete unrelated policies.

Reuse the `ask_office` function from lesson 19 in this terminal. If the client Pod is missing, follow that lesson's client creation and readiness steps first. The helper runs Ruby HTTP requests inside service-client, so requests take the cluster network path rather than a host port-forward.

```bash
ask_office a /seat
ask_office b /seat
```

Both should return HTTP 200 with the same booking. The original experiment continued with Alice already booked. If both are empty on a fresh replay, establish that state:

```bash
ask_office b /book '{"customer":"Alice"}'
ask_office a /seat
ask_office b /seat
```

Only run that booking command when empty; expect 201. Record the booking ID. If already occupied, keep the existing booking and use its ID for comparison. Do not restart A to prepare this test: its booking state lives in process memory.

## 2. Identify the allowed client

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  label pod service-client role=client --overwrite

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  get pods --show-labels
```

The client must carry role=client BEFORE the policy is applied. Otherwise the policy also blocks our test requests. Labelling an existing Pod does not restart it. If you later recreate service-client, apply the label again: this label was added to that particular Pod.

<details>
<summary>3. Understand the manifest</summary>

## 3. Understand the manifest

```bash
cat k8s/partition-offices.yaml
```

The committed file includes explanatory comments. Its resource structure is:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: partition-offices
  namespace: cap-lab
spec:
  podSelector:
    matchExpressions:
      - key: app
        operator: In
        values:
          - office-a
          - office-b
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: client
      ports:
        - protocol: TCP
          port: 4567
```

| Section | Connection to our resources |
| --- | --- |
| metadata.namespace | Limits this policy's scope to cap-lab. |
| spec.podSelector | Selects destination Pods using the existing app labels on both Deployment templates. |
| matchExpressions / In | Matches either office-a or office-b. |
| policyTypes / Ingress | Restricts incoming connections to those selected Pods. |
| ingress / from / podSelector | Allows source Pods labelled role=client in the same namespace. |
| ports | Allows that source to connect to destination TCP port 4567, where Puma listens. |

The policy allows client-to-A and client-to-B. B has no role=client label, so B-to-A fails at A's incoming boundary. Outgoing traffic is not isolated by this policy; that does not override restrictions at the destination. Services still select their office Pods, but a Service does not bypass Pod network policy. DNS is not blocked by this ingress-only rule.

This rule is broader than blocking just one pair: other ordinary Pod sources without the client label also lose access to the selected offices. NetworkPolicy has no understanding of HTTP routes, customers, or booking state. The role label is a lab traffic selector, not user authentication.

</details>

## 4. Apply the partition

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  apply -f k8s/partition-offices.yaml

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  describe networkpolicy partition-offices
```

Apply stores the desired policy; the network implementation then enforces it. Allow a few seconds for convergence. A successful apply alone does not prove enforcement. K3s includes a NetworkPolicy controller by default unless disabled; our traffic checks establish behavior in this lab.

## 5. Observe the partition

```bash
ask_office a /health
ask_office b /health
ask_office a /seat
ask_office b /seat
ask_office b /book '{"customer":"Bob"}'
kubectl --context=k3d-cap-kub-lab -n cap-lab get pods
```

| Check | Expected replay outcome | Why |
| --- | --- | --- |
| A /health | 200 | Client can reach A's local health handler. |
| B /health | 200 | Client can reach B's local health handler. |
| A /seat | 200, original booking | A reads its own memory. |
| B /seat | 503, Cannot reach authority | B cannot forward its read to A. |
| B /book | 503, Cannot reach authority | B cannot obtain an authoritative booking decision. |
| Office readiness | Both 1/1 Running | Local health does not test authority access. |

Kubernetes permits traffic from a Pod's own node, including the kubelet probe path. The readiness probe also sets Host: localhost to satisfy the application's host check. Neither local health nor readiness guarantees that an operation depending on another office can succeed.

The client successfully receiving B's HTTP 503 is useful evidence: it reached B, and B reported failure of the downstream operation. CAP availability is not established merely by returning an HTTP error response.

## 6. Heal the partition before finishing

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  delete -f k8s/partition-offices.yaml

ask_office b /seat
ask_office b /book '{"customer":"Bob"}'
ask_office a /seat
```

Allow a short convergence interval if necessary. Expect B's read to return 200 with the original ID; Bob's booking to return 409 because the seat is already occupied; and A's read to show the same original booking. Removing the policy restores communication without restarting the offices.

Deleting with -f removes the cluster resource, not the YAML file on disk. Keep that file so the experiment remains reproducible. End with the policy absent and the booking retained. The client label may remain.

<details>
<summary>Observed learner evidence</summary>

## Observed learner evidence

The learner supplied these results before committing e267954:

- A /health returned 200 with {"status":"ok"}.
- A /seat returned 200 with Alice's booking, conflict=false.
- B /seat and B /book returned 503 with "Cannot reach authority".
- Both office Pods and service-client were 1/1 Running.
- After policy deletion, B /seat returned 200 with the original booking, B /book for Bob returned 409, and A /seat returned 200 with the same booking.

The original booking was:

```json
{"id":"56516fce-652f-4b0b-9c7a-cd846f4d65ae","seat":"A1","customer":"Alice","office":"a"}
```

Your replay UUID will differ. Compare it across requests rather than expecting this literal value.

The observed failure body was:

```json
{"error":"Cannot reach authority","office":"b","detail":"A booking may have completed before communication failed."}
```

That detail is a generic application message, also emitted for GET. It does not prove that a booking completed. In a general communication failure, losing a reply can leave a write's outcome uncertain; this experiment's recovery reads showed only Alice's original booking.

B's explicit /health output was not supplied; its 200 result remains an expected replay check, not recorded evidence. A's Pod listing showed one container restart 53 minutes earlier. The listing does not establish a restart during this experiment, and it must not be recorded as zero restarts. The same booking ID before and after healing is the observed continuity evidence.

These are learner-supplied results, not a separate automated validation run.

</details>

## If results differ

- Client requests time out for both offices: inspect service-client's role=client label, readiness, and policy selectors first.
- B still returns 200 during isolation: allow propagation, retry a new request, inspect other additive policies and whether NetworkPolicy enforcement is enabled. Do not conclude success from apply output alone.
- B returns 503 after healing: confirm policy removal, then inspect A's readiness, Service endpoints, and B's authority URL using the earlier lessons.
- Health returns 403: investigate the application's Host permission settings; an HTTP rejection is different from a dropped network connection.
- Booking disappears or changes ID: inspect Pod/container restarts. NetworkPolicy does not make process memory durable.

## What we learned and commit order

With one authority, the isolated office refused operations instead of inventing its own booking decision. This demonstrates the consistency-versus-availability choice during a partition. It is not proof of production-grade consistency across crashes, multiple authority replicas, or every failure scenario.

The implementation was committed first at e267954. This note was written afterward against that verified checkpoint. Commit documentation separately after review. A later lesson can switch to local decisions and asynchronous replication to compare the other tradeoff using the same network boundary.

References: [Kubernetes NetworkPolicy semantics](https://kubernetes.io/docs/concepts/services-networking/network-policies/) and [K3s networking services](https://docs.k3s.io/networking/networking-services).

---

Next: [21 — Local booking and asynchronous replication in Kubernetes](21-kubernetes-local-replication.md).
