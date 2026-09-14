# 22 — Available local bookings, then conflict after recovery

## Checkpoint and learning objective

Source checkpoint: `6a863177b187d304f292f97eb812b2a60cf25d01` (`6a86317`). This experiment reuses the local-mode Deployments and existing partition-offices NetworkPolicy manifest; no new implementation is required.

Continue from [21 — local replication baseline](21-kubernetes-local-replication.md). Both offices must run COORDINATION_MODE=local with reciprocal PEER_URL Service addresses. Use the original Ubuntu checkout, existing k3d-cap-kub-lab cluster and cap-lab namespace, and the service-client Pod and ask_office helper from [lesson 19](19-two-offices-in-kubernetes.md).

Prediction: during isolation, A confirms Alice and B confirms Bob for seat A1. When communication returns, both offices retain both records and report conflict=true. We are testing the application's behavior under partition, not asking Kubernetes to resolve a business conflict.

## 1. Reset both offices together

This deliberately discards the previous in-memory bookings. Keep the manifests and Services. Scale the live Deployments to zero:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  scale deployment office-a office-b --replicas=0

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  wait --for=delete pod \
  -l 'app in (office-a,office-b)' --timeout=120s

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  get pods -l 'app in (office-a,office-b)'
```

Require no office Pods before continuing. If wait reports no matching resources, the final get verifies they already disappeared. If deletion times out, investigate before starting replacements.

Why zero first? Restarting one office while the other survives can refill the new process from the surviving peer's records. Removing both processes first leaves neither with old records to send back. This is a controlled lab reset, not a persistence strategy. The Services and Deployment objects remain; the YAML files still declare one replica.

## 2. Establish the partition before starting replacements

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  label pod service-client role=client --overwrite

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  apply -f k8s/partition-offices.yaml

kubectl --context=k3d-cap-kub-lab -n cap-lab get networkpolicy
```

The policy permits role=client Pods in cap-lab to connect to the offices on TCP 4567. It restricts ingress to both app=office-a and app=office-b Pods, excluding each office as a permitted source. The selectors match the replacement Pods automatically. See [lesson 20](20-kubernetes-network-partition.md) for the annotated policy explanation.

Other policies can add permissions, so investigate any unexpected policies before assuming isolation. A stored policy alone is not proof of enforcement. We check the records under isolation below.

## 3. Start and verify both offices

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  scale deployment office-a office-b --replicas=1

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  rollout status deployment/office-a --timeout=120s

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  rollout status deployment/office-b --timeout=120s

ask_office a /health
ask_office b /health
ask_office a /seat
ask_office b /seat
```

Require HTTP 200 from both health endpoints and empty booking arrays from both seat endpoints. Wait for both rollouts so the following requests target the intended new processes. If either office contains records, stop and check the reset before booking.

All kubectl examples explicitly name the context and namespace. Some original pasted commands omitted them and succeeded using the learner's current defaults. Replays should retain the explicit flags to avoid operating on a different cluster or namespace.

## 4. Create one record and check isolation

```bash
ask_office a /book '{"customer":"Alice"}'
sleep 6
ask_office a /seat
ask_office b /seat
```

Expect A's booking response to be 201, with office=a. A should show Alice; B should remain empty despite opportunities for the replication loop to run. Six seconds is a convenient observation interval, not a timing guarantee. If B contains Alice, stop: communication was not isolated as intended.

A single empty read is not definitive evidence of a partition because replication is asynchronous. Together, the applied policy, repeated separate reads, and delivery after policy removal provide the experiment's evidence. Replication error logs can help diagnose unexpected behavior.

## 5. Let B decide independently

```bash
ask_office b /book '{"customer":"Bob"}'
ask_office a /seat
ask_office b /seat
```

Expect B's booking to return 201 with office=b. At this point:

| Office | Known records | Local conflict flag |
| --- | --- | --- |
| A | Alice only | false |
| B | Bob only | false |

Both confirmed the same seat. Each local flag says only that this process knows one booking. It cannot establish global agreement while records are missing.

Compare [authority mode](20-kubernetes-network-partition.md): B returned 503 when unable to reach A. Local mode completes booking operations during isolation, but those local decisions can violate the single-seat rule across offices.

## 6. Restore communication without restarting

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  delete -f k8s/partition-offices.yaml

sleep 6
ask_office a /seat
ask_office b /seat
```

Delete the policy once. If it is already absent, inspect the cluster state rather than repeatedly deleting. Policy removal does not delete its YAML file.

Expect both offices to hold Alice and Bob, with conflict=true. If delivery is still pending, repeat the reads after a few seconds. Compare the set of record IDs, not array order. The receiver retains records by ID; independent records are not duplicates just because they name the same seat.

Do not restart either office to heal the partition: restarting would introduce data loss and change what this experiment measures.

## 7. Try a third customer

```bash
ask_office a /book '{"customer":"Charlie"}'
ask_office b /book '{"customer":"Charlie"}'
```

Expect both to return 409 with the known records. This prevents a third booking; it does not undo either earlier confirmation or select a winner.

## Observed learner evidence

Both rollouts completed successfully. Both health endpoints returned 200, and both initial seat reads returned 200 with empty records.

A confirmed Alice with HTTP 201:

```json
{"confirmed":true,"booking":{"id":"cd026122-2bb1-4338-abca-345bad1bd773","seat":"A1","customer":"Alice","office":"a"}}
```

B remained empty on two supplied reads before confirming Bob with HTTP 201:

```json
{"confirmed":true,"booking":{"id":"0b85b604-13f5-4577-a5fc-96f845d15de9","seat":"A1","customer":"Bob","office":"b"}}
```

Before recovery, each office showed only its own record and conflict=false. The learner then supplied successful policy deletion output. After recovery, A returned HTTP 200:

```json
{"seat":"A1","available":false,"conflict":true,"bookings":[{"id":"cd026122-2bb1-4338-abca-345bad1bd773","seat":"A1","customer":"Alice","office":"a"},{"id":"0b85b604-13f5-4577-a5fc-96f845d15de9","seat":"A1","customer":"Bob","office":"b"}]}
```

B returned the same two IDs in reverse order, also HTTP 200 and conflict=true. Both Charlie booking attempts returned HTTP 409 and both records.

The supplied output begins at scale-up; the scale-down, deletion wait, and policy-apply outputs were not included. Empty initial reads and the subsequent behavior were supplied. Do not claim an observed exact delay or an independently verified reset sequence. These are learner-provided results, not an automated runtime validation.

Your replay UUIDs will differ. The important evidence is that each confirmed ID survives and appears at both offices after recovery.

## Connect the dots

| Question | Authority-mode experiment | Local-mode experiment |
| --- | --- | --- |
| Can isolated B complete a booking? | No: 503 when A is unreachable. | Yes: 201 using local records. |
| Can the offices independently confirm the same seat? | B delegates to the single authority. | Yes, before learning the other decision. |
| What does healing accomplish? | Restores access to the authority. | Delivers missing records and exposes the conflict. |

Convergence means the offices eventually hold the same records under successful continued delivery. It does not mean the business state is valid. Here both agree that two customers were confirmed for one seat.

This demonstrates the tradeoff under the tested partition. It does not prove every property of an available distributed system, nor provide crash durability. The lab uses in-memory state, one process per office, and a simple replication loop. A real booking system needs an explicit strategy to prevent competing confirmations or resolve them; merely copying records cannot make both original promises valid.

## Troubleshooting and final state

- B returns 409 for Bob with Alice already present: verify isolation before repeating the experiment.
- Both client requests fail: check the service-client label, Pod readiness, and policy rules.
- Only one record survives recovery: inspect reset/restart events and replication logs rather than assuming a merge policy chose a winner.
- Offices stay different after healing: confirm policy removal, peer URLs, Services, and replication logs.
- Array order differs: compare IDs; that alone is not a mismatch.

End with the policy absent, both Deployments at one replica, and both offices retaining the two conflicting records. Preserve this state until the next lesson specifies any reset.

No application or manifest change was needed. Review and commit this documentation together with any still-pending lesson 21 documentation; the source checkpoint remains 6a86317.
