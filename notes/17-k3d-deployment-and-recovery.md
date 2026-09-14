# 17 — Run an office in Kubernetes and observe Pod replacement

A Deployment replaces a deleted Pod. It restores a running office, but it does not restore the booking that lived in the old process’s memory.

[All lessons](README.md)

## Checkpoint and reading order

Source commit: `271f190295684537f36f0c779c972d7ae14c773f` (`271f190`) — Deploy ticket office and Headlamp to the local Kubernetes lab.

This note covers cluster setup and Deployment before the optional Headlamp steps in [lesson 16](16-headlamp-dashboard.md), then the observed Pod replacement experiment. Read this setup first if you do not yet have a cluster. Kubernetes lessons use the original application checkout, not the Docker tutorial worktree or its dc helper.

The learner supplied Ready node output, booking responses before/after replacement, and confirmed expected behavior. The new Pod name was not pasted. We do not invent its name or claim that port-forward resumes automatically.

## 1. Check the existing environment

In Ubuntu:

```bash
cd ~/cap-kub-lab
docker info --format '{{.OSType}}'
k3d cluster list
kubectl config current-context
```

Require Docker to report linux. If cap-kub-lab already exists, inspect it rather than creating/deleting it again. This lesson assumes the committed app and manifest at 271f190. For a later checkout, use a separate worktree of that commit if an exact replay is needed; do not overwrite current development files.

For a fresh cluster only:

```bash
k3d cluster create cap-kub-lab \
  --servers 1 \
  --agents 2 \
  --kubeconfig-switch-context=false
```

This creates three Kubernetes nodes as Docker containers: one server/control plane and two agents. It adds connection information without switching the default context. Two workers do not automatically create two application replicas. The learner also explicitly selected the context with `kubectl config use-context k3d-cap-kub-lab`; our commands select it explicitly so the default need not change.

```bash
kubectl --context=k3d-cap-kub-lab wait \
  --for=condition=Ready nodes --all --timeout=120s
kubectl --context=k3d-cap-kub-lab get nodes -o wide
docker ps --filter "name=k3d-cap-kub-lab"
```

Observed: all three nodes Ready, running k3s v1.35.5+k3s1 and containerd. The worker ROLES value was <none>, which does not mean they are unusable. Docker also showed k3d-tools and serverlb; these are support containers, not extra Kubernetes nodes. k3d 5.9.0 was used. Future defaults can differ; this is the observed version, not a guarantee from an unpinned create command.

## 2. Build the image, then import it

```bash
docker build -t cap-kub-office:v1 .
k3d image import cap-kub-office:v1 -c cap-kub-lab
```

Build uses the source in the current directory. Import makes the image available to the nodes' containerd runtimes. A host Docker image is not automatically available to Kubernetes. The manifest uses imagePullPolicy Never, so an absent imported image causes a visible error rather than a registry pull.

For exact historical replay, build from this commit. Do not silently reuse the v1 tag for later code while claiming it is the same image; use a new tag for later application changes and import it before updating the manifest.

## 3. Read and apply the Deployment

```bash
cat k8s/office-a.yaml
kubectl --context=k3d-cap-kub-lab create namespace cap-lab
kubectl --context=k3d-cap-kub-lab apply -f k8s/office-a.yaml
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  rollout status deployment/office-a --timeout=120s
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  get deployments,replicasets,pods -o wide
```

If namespace creation says AlreadyExists, continue; other errors require investigation. Namespace must exist before applying the namespaced manifest.

Deployment requests one replica. Its selector matches app: office-a in its Pod template. The Deployment manages a ReplicaSet, which maintains Pods. Each Pod contains our Sinatra/Puma container. OFFICE=a and COORDINATION_MODE=authority make A serve locally with no background replication.

The Pod may run on the server node; this k3s server also accepts workloads. The observed initial Pod did run there. containerPort 4567 documents the application port; it does not publish a host port.

## 4. Readiness failure encountered and fixed

The original first Pod reported Running, Ready False, restart count 0, and repeated readiness HTTP 403. It had started successfully; the application rejected the probe's Host value based on the Pod IP.

The committed manifest already contains the correction:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: http
    httpHeaders:
      - name: Host
        value: localhost
  initialDelaySeconds: 2
  periodSeconds: 2
```

Kubelet still connects to the Pod IP, but supplies an allowed HTTP hostname. Do not use httpGet.host: localhost; that changes the connection destination. Readiness marks eligibility for traffic, not automatic restart. No liveness probe is defined here.

If rollout fails:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  describe pods -l app=office-a
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  logs deployment/office-a --tail=40
```

Read Events: a missing imported image, a failing probe, and a crashed process are different causes. The prerequisite for the next step is READY 1/1 and Running.

Optionally install Headlamp using lesson 16 now. It is for observation; it does not change the booking protocol.

## 5. Connect to the office

In terminal A:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  port-forward deployment/office-a 24567:4567
```

Keep it running. This selects a Pod through the Deployment and tunnels to its container port. There is no office Service yet. The tunnel is tied to a selected Pod, not a permanent address that automatically follows every replacement.

In terminal B:

```bash
curl -i http://localhost:24567/seat
curl -i http://localhost:24567/book \
  -H 'Content-Type: application/json' \
  -d '{"customer":"Alice"}'
curl -i http://localhost:24567/seat
```

For the empty initial Pod, expect 201 and an Alice record. If already occupied, use that existing booking as the before-state rather than assuming a second booking should succeed.

Actual observed Alice ID: `3c9b2c61-e4c2-4aa0-a40c-8a949eee75b6`. The POST returned confirmed true, office a. Subsequent GET returned available false, conflict false, and that one record.

## 6. Delete the Pod, not the desired state

Record its current name in Headlamp or kubectl, then:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  get pods -l app=office-a
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  delete pod -l app=office-a
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  get pods -l app=office-a -w
```

The selector deletes this Deployment's office Pods; at this checkpoint it has one replica. The ReplicaSet still requests one, so Kubernetes creates a replacement. Expect a different Pod name becoming 1/1 Running. Ctrl+C stops watching, not the Pod. Headlamp's read-only viewer can observe this but cannot initiate the deletion.

## 7. Reconnect and compare data

The old port-forward normally ends when its Pod disappears. If still active, stop it with Ctrl+C before re-running in terminal A:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  port-forward deployment/office-a 24567:4567
```

In terminal B:

```bash
curl -i http://localhost:24567/seat
```

Observed after recovery:

```text
HTTP/1.1 200 OK
{"seat":"A1","available":true,"conflict":false,"bookings":[]}
```

The transcript also included `curl: (52) Empty reply from server` between successful reads. This is consistent with an interrupted connection during replacement, not an application HTTP response. The exact intermediate error can vary.

## Conclusion and checkpoint

Kubernetes restored the requested running process count. It did not restore Ruby memory. Service availability and durable application state are different responsibilities. The learner confirmed replacement worked as predicted; the pasted booking/empty responses demonstrate state loss.

After these checks, the learner committed 271f190, containing office-a.yaml, headlamp-install.yaml, and the initial Headlamp note. This note and the Headlamp verification update follow that source commit. No new app code is needed to repeat the experiment.

End state: replacement office Pod ready, empty bookings, Deployment still present. Closing port-forward does not stop it. Leave the cluster intact for the next lesson: a Service gives the office stable in-cluster discovery, but does not make its memory persistent.

---

Next: [18 — A stable Service can follow replacement Pods](18-service-discovery.md).
