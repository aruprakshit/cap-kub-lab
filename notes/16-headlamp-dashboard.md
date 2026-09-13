# 16 — Inspect the Kubernetes lab with Headlamp

## Purpose and current status

Headlamp provides a browser UI for inspecting Pods, Deployments, events, and logs. It does not require moving the application to GitOps or Argo CD. Its login permissions come from Kubernetes RBAC.

Installation checkpoint: `271f190295684537f36f0c779c972d7ae14c773f` (`271f190`). The learner confirmed Headlamp was up and running in the browser. The installation manifest and this guide were committed with the first office Deployment. Browser verification is learner-confirmed; no screenshot or token was recorded. For cluster creation and the office Deployment, begin with [lesson 17](17-k3d-deployment-and-recovery.md).

## Prerequisites and terminal location

Use Ubuntu WSL with Docker running and the existing `k3d-cap-kub-lab` Kubernetes context. No Helm, Headlamp desktop app, or additional host programming language is required.

Run from the ORIGINAL application checkout, not the historical Docker tutorial worktree:

```bash
cd ~/cap-kub-lab
kubectl --context=k3d-cap-kub-lab get nodes
```

Require the lab's nodes to be Ready. Every command below explicitly selects this cluster. Headlamp can help inspect an unready office Pod; office readiness is not a prerequisite for installing the dashboard.

## 1. Obtain the official installation manifest

If `k8s/headlamp-install.yaml` is already present in your checkout, use that saved copy and skip the download. To obtain it for the first time:

```bash
mkdir -p k8s
curl -fL \
  https://raw.githubusercontent.com/kubernetes-sigs/headlamp/main/kubernetes-headlamp.yaml \
  -o k8s/headlamp-install.yaml
```

`-f` makes HTTP errors fail; `-L` follows redirects; `-o` saves the manifest. Stop if download fails. Inspect it before applying:

```bash
cat k8s/headlamp-install.yaml
```

The official manifest used during this lesson creates a Deployment and Service named headlamp in kube-system. The Service accepts port 80 and forwards to the application's container port 4466. The fetched manifest also includes a headlamp-admin token Secret; our viewer login below does not use that Secret or create an admin account.

The upstream main branch can change, and the observed manifest uses an image tagged latest. Saving the YAML records its contents, but does not pin that image's bytes. Do not claim this is a fully version-pinned install. Review/pin a release or digest when making the tooling reproducible across future versions.

Official reference: [Headlamp in-cluster installation](https://headlamp.dev/docs/latest/installation/in-cluster/).

## 2. Apply and wait for the UI server

```bash
kubectl --context=k3d-cap-kub-lab \
  apply -f k8s/headlamp-install.yaml

kubectl --context=k3d-cap-kub-lab -n kube-system \
  rollout status deployment/headlamp --timeout=300s
```

Apply creates or updates the resources. Rollout waits for the Deployment's readiness; container creation alone is not enough. An initial image pull and readiness-probe delay can take time.

Inspect the Pod and Service separately:

```bash
kubectl --context=k3d-cap-kub-lab -n kube-system \
  get pods -l k8s-app=headlamp

kubectl --context=k3d-cap-kub-lab -n kube-system \
  get service headlamp
```

Require the Headlamp Pod to be Ready (normally 1/1 Running) and the Service to exist. Query the Service by name because its metadata may not carry the Pod's label. A Service selector selects Pods; that does not automatically label the Service itself.

## 3. Create a read-only login identity

```bash
kubectl --context=k3d-cap-kub-lab -n kube-system \
  create serviceaccount headlamp-viewer

kubectl --context=k3d-cap-kub-lab \
  create clusterrolebinding headlamp-viewer \
  --clusterrole=view \
  --serviceaccount=kube-system:headlamp-viewer
```

The ServiceAccount is an identity. The ClusterRoleBinding grants that identity the built-in view role across namespaces. This lets you inspect common workloads, including their Pods, Deployments, and logs, without granting administrator access. Some administrative pages and resources will be unavailable.

If either command returns AlreadyExists, inspect the existing resource before continuing:

```bash
kubectl --context=k3d-cap-kub-lab -n kube-system \
  get serviceaccount headlamp-viewer

kubectl --context=k3d-cap-kub-lab \
  get clusterrolebinding headlamp-viewer -o yaml
```

Check roleRef is view and the subject is kube-system/headlamp-viewer. Do not assume an existing binding grants the intended permissions.

Optional permission check:

```bash
kubectl --context=k3d-cap-kub-lab auth can-i list pods \
  -n cap-lab \
  --as=system:serviceaccount:kube-system:headlamp-viewer
```

Expected yes. This check uses your current administrator connection to impersonate the viewer for authorization testing; it does not log your browser in.

Official reference: [Headlamp authentication](https://headlamp.dev/docs/latest/installation/).

## 4. Open a local browser connection

In terminal A:

```bash
kubectl --context=k3d-cap-kub-lab -n kube-system \
  port-forward service/headlamp 8080:80
```

Keep this command running. Open [http://localhost:8080](http://localhost:8080) in your browser. Use HTTP, not HTTPS, for this Service/port-forward setup.

```text
Browser localhost:8080
  -> kubectl port-forward (selects a Pod through the Service)
  -> Headlamp container port 4466
```

`8080:80` means local port 8080 maps to Service port 80, whose targetPort is 4466. Port-forward establishes a tunnel through Kubernetes; it does not require a public Ingress or cloud load balancer. Ctrl+C ends the tunnel, not Headlamp's Deployment. If the selected Pod is replaced, restart the port-forward command.

## 5. Create a short-lived login token

In terminal B:

```bash
kubectl --context=k3d-cap-kub-lab -n kube-system \
  create token headlamp-viewer --duration=1h
```

Paste the returned token into Headlamp's token login field. This requests a one-hour lifetime; the API server controls the actual granted duration. Generate another token when login expires.

Do not save the token in Git, this guide, a screenshot shared publicly, or the chat. The manifest and commands are shareable; credentials are not needed to reproduce the setup.

## 6. Inspect office-a

In the UI, select namespace cap-lab and find its Deployments and Pods (navigation wording can vary by Headlamp version):

1. Open Deployment office-a and inspect desired/ready replicas.
2. Open its Pod and inspect container state and readiness conditions.
3. View Pod events and container logs.
4. Compare with the CLI:

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  get deployments,replicasets,pods -o wide

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  describe pods -l app=office-a
```

Running and Ready are different. The earlier office readiness issue returned HTTP 403 because the probe's Pod-IP Host was not permitted by Sinatra. Its manifest fix sends Host: localhost in the probe's httpHeaders. Headlamp makes that state visible; installing Headlamp does not repair the office automatically.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Headlamp rollout times out | Describe the Headlamp Pod and inspect logs/events before retrying |
| ImagePullBackOff | Check the event message for registry/network/image errors |
| localhost:8080 does not load | Confirm port-forward is still running and using the correct context/namespace |
| Port 8080 already in use | Use `port-forward service/headlamp 8081:80` and open localhost:8081 |
| Login rejects token | Generate a fresh token from the same cluster and verify viewer binding |
| Some pages show Forbidden | The viewer has limited permissions; do not automatically promote it to admin |
| office-a is missing | Select cap-lab and compare the CLI results for the same context |

Diagnostic commands:

```bash
kubectl --context=k3d-cap-kub-lab -n kube-system \
  describe pods -l k8s-app=headlamp

kubectl --context=k3d-cap-kub-lab -n kube-system \
  logs deployment/headlamp --tail=50
```

## Completion and commit checkpoint

The setup is verified when the Headlamp Pod is Ready, browser login succeeds, and the UI displays office-a's Deployment/Pod consistently with kubectl. The learner has confirmed successful setup. For replay, report errors without including the token.

The original successful setup was committed in 271f190. For future changes, commit the intended manifest and updated note after verifying them. Do not claim a successful browser check before it has been done. Read-only viewer identity/binding commands are recorded here; they are not contained in the upstream install manifest and must also be run on a fresh cluster.

For a temporary pause, Ctrl+C the port-forward. Headlamp stays installed and no application booking state is changed by closing the browser or ending the tunnel.
