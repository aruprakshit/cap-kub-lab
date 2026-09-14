# 18 — A stable Service can follow replacement Pods

A Service gives the client a stable destination while Pod IPs change. Check both the endpoint update and a real request after replacement.

[All lessons](README.md)

## Checkpoint and prerequisites

Source commit: `1005f164770ba526272406696046388499acfd41` (`1005f16`) — Add a ClusterIP Service for stable office A discovery.

Start after [lesson 17](17-k3d-deployment-and-recovery.md): the cap-kub-lab k3d cluster exists, image cap-kub-office:v1 is imported, namespace cap-lab exists, and Deployment office-a has one Ready Pod. Run in Ubuntu from the original application checkout, not the historical Docker tutorial worktree. No application code changes are required.

The learner pasted an initial successful Service request and before/after resource output. The learner subsequently confirmed that the client request after Pod replacement returned HTTP 200. This final result is learner-confirmed; a separate raw response was not pasted.

## 1. Understand the resource connections

Read the fully commented committed manifest:

```bash
cat k8s/office-a-service.yaml
```

It declares one Service named office-a in cap-lab. type ClusterIP allocates an internal virtual IP; it does not publish a laptop port. The selector app: office-a matches the Deployment's POD TEMPLATE labels. Sharing the Deployment's name does not create the association.

Service port 4567 is the client-facing port. targetPort: http finds the named container port http, declared as containerPort 4567 in the selected Pod. The Service port's own name is a separate name.

```text
Client -> DNS name office-a -> Service ClusterIP:4567
                                 -> Ready matching Pod:4567
```

The Deployment/ReplicaSet creates Pods. The Service selects Pods. Kubernetes maintains EndpointSlices describing those destinations. The Service does not own Pods and does not preserve their application memory.

## 2. Apply and inspect

```bash
kubectl --context=k3d-cap-kub-lab apply -f k8s/office-a-service.yaml
kubectl --context=k3d-cap-kub-lab -n cap-lab get service office-a -o wide
kubectl --context=k3d-cap-kub-lab -n cap-lab get pods -l app=office-a -o wide
kubectl --context=k3d-cap-kub-lab -n cap-lab get endpointslices \
  -l kubernetes.io/service-name=office-a -o wide
```

Require the Service port to be 4567/TCP and the endpoint to correspond to the Ready office Pod. If no destination appears, check labels and readiness before attempting to interpret a traffic failure.

The original before-state was:

| Resource | Observed value |
| --- | --- |
| Service ClusterIP | 10.43.122.132 |
| Pod | office-a-6dbc5447d6-8phzm |
| Pod IP | 10.42.1.5 |
| EndpointSlice | office-a-vdggr, destination 10.42.1.5 |

These addresses and names are observations, not values to put in YAML.

## 3. Create an in-cluster client

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab run service-client \
  --image=cap-kub-office:v1 \
  --image-pull-policy=Never \
  --restart=Never \
  --command -- ruby -e 'sleep'

kubectl --context=k3d-cap-kub-lab -n cap-lab wait \
  --for=condition=Ready pod/service-client --timeout=120s
```

The command overrides the image's normal startup, so this Pod waits rather than starting another office. It uses the imported Ruby image and needs no host runtime. restart Never creates a standalone Pod; a Deployment will not recreate it after deletion. If service-client already exists, inspect/reuse it rather than assuming a second create succeeded.

Send a request:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab exec service-client -- ruby -rnet/http -e '
  uri = URI("http://office-a:4567/seat")
  response = Net::HTTP.start(
    uri.host, uri.port, nil,
    open_timeout: 2, read_timeout: 5
  ) { |http| http.get(uri.request_uri) }
  puts response.code
  puts response.body
'
```

The client is in cap-lab, so the short DNS name office-a refers to the Service in that namespace. It is also an allowed Sinatra hostname. This request exercises in-cluster Service routing, not host port-forwarding.

Actual initial output:

```text
200
{"seat":"A1","available":true,"conflict":false,"bookings":[]}
```

The original learner then deleted the client. For this streamlined replay, keep it running until the final request; it is independent of the office Pod.

## 4. Replace only the office Pod

After recording the Service/Pod/endpoint values:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab delete pod -l app=office-a
kubectl --context=k3d-cap-kub-lab -n cap-lab get pods -l app=office-a -w
```

Wait for the replacement to show 1/1 Running, then Ctrl+C to stop watching. The Deployment still requests one replica. A Pod's IP may be reused in general, so a different IP is not guaranteed; the Pod identity changes.

Re-run the three inspection commands from step 2. Actual observed after-state:

| Resource | Before | After |
| --- | --- | --- |
| Service ClusterIP | 10.43.122.132 | 10.43.122.132 |
| Pod suffix | 8phzm | jgv2d |
| Pod IP | 10.42.1.5 | 10.42.1.6 |
| EndpointSlice name | office-a-vdggr | office-a-vdggr |
| EndpointSlice destination | 10.42.1.5 | 10.42.1.6 |

The slice was updated in place, and the Service retained its IP. A stable address is not continuous availability: with one replica, there can be a period without a Ready destination during replacement.

## 5. Verify the actual traffic path after replacement

Repeat the exact Ruby request from step 3. If you deleted service-client earlier, recreate it and wait for readiness using step 3 first. Expected HTTP 200 from the same URL, office-a:4567, without inserting the new Pod IP into client code.

This final request verifies delivery, beyond observing that Kubernetes metadata changed. The learner confirmed this final request returned HTTP 200. The same Service URL successfully reached the replacement Pod; this is a confirmed outcome rather than a separately captured response transcript.

## 6. Remove only the temporary client

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab delete pod service-client
```

The office Deployment and Service remain. Closing a terminal or deleting this client does not delete the Service.

## Learning and commit

A Service gives stable in-cluster discovery while selected Pod destinations change. Stability lasts for the lifetime of the Service; deleting/recreating the Service can allocate a different ClusterIP. Neither the Service nor the replacement process restores in-memory bookings.

The learner committed 1005f16, including the commented Service manifest and earlier documentation updates. This note references that commit. All requested checks are now confirmed, including HTTP 200 after replacement. On replay, perform step 5 before advancing. No additional source commit is needed solely for this verification.

---

Next: [19 — Two Services, one booking authority](19-two-offices-in-kubernetes.md).
