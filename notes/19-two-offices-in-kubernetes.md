# 19 — Two Services, one booking authority

## Checkpoint and prerequisites

Source: `c49c141fd2076e3bca9fb139b75479f9e074fc7d` (`c49c141`) — Deploy office B with Service-based forwarding to office A.

Start after [lesson 18](18-service-discovery.md): cluster k3d-cap-kub-lab, namespace cap-lab, imported cap-kub-office:v1, and a Ready office A Deployment with its Service. A should have empty booking state after the previous replacement experiment. Run in Ubuntu from the original application checkout. No new application image is needed for this configuration-only change.

## 1. Read the new resources

```bash
cat k8s/office-b.yaml
cat k8s/office-b-service.yaml
```

The Deployment requests one Pod labeled app: office-b. It uses the same image as A but sets OFFICE=b, COORDINATION_MODE=authority, and AUTHORITY_URL=http://office-a:4567. The Service selects that Pod label and maps its port 4567 to named container port http.

```text
Client -> Service office-b -> Pod B
                               -> Service office-a -> Pod A
```

Names are resolved inside cap-lab. Do not substitute a Pod IP for the authority URL. Sharing a name does not connect a Deployment to a Service; matching Pod labels and the Service selector do.

B's readiness probe calls its LOCAL /health with Host: localhost. This checks B's process, not reachability of A. It is intentionally possible for B to remain Ready while an authoritative operation fails; the next experiment tests that distinction.

## 2. Apply and wait

```bash
kubectl --context=k3d-cap-kub-lab \
  apply -f k8s/office-b.yaml -f k8s/office-b-service.yaml

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  rollout status deployment/office-b --timeout=120s

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  get deployments,pods,services -o wide
```

Require both office Pods 1/1 Running before business requests. Apply does not rebuild an image; environment settings configure the existing imported code. If B is not ready, inspect describe/logs before continuing.

## 3. Create or reuse the client Pod

```bash
kubectl --context=k3d-cap-kub-lab -n cap-lab \
  run service-client \
  --image=cap-kub-office:v1 \
  --image-pull-policy=Never \
  --restart=Never \
  --command -- ruby -e 'sleep'

kubectl --context=k3d-cap-kub-lab -n cap-lab \
  wait --for=condition=Ready pod/service-client --timeout=120s
```

If service-client already exists, inspect it and reuse it if it is the expected running client. Do not treat AlreadyExists as proof of readiness. The command override starts a waiting Ruby process rather than another office.

Define this function in the same Ubuntu terminal:

```bash
ask_office() {
  kubectl --context=k3d-cap-kub-lab -n cap-lab \
    exec service-client -- ruby -rnet/http -e '
      office, path, body = ARGV
      uri = URI("http://office-#{office}:4567#{path}")
      req = body ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      if body
        req["Content-Type"] = "application/json"
        req.body = body
      end
      response = Net::HTTP.start(
        uri.host, uri.port, nil,
        open_timeout: 2, read_timeout: 10
      ) { |http| http.request(req) }
      puts "HTTP #{response.code}"
      puts response.body
    ' "$@"
}
```

This runs HTTP requests inside the Kubernetes client Pod, not a Docker client container. The first argument is a or b, the second is a path, and the optional third is JSON for POST. Quote JSON so the shell passes one argument. Redefine the function after opening a new terminal; it is not a permanent executable.

## 4. Establish empty state

```bash
ask_office a /seat
ask_office b /seat
```

Both actual responses were HTTP 200:

```json
{"seat":"A1","available":true,"conflict":false,"bookings":[]}
```

If already occupied, stop before predicting a successful new booking. For a deliberate clean replay only, delete A's Pod and wait for its replacement as in lesson 17, acknowledging that this erases A's volatile state. Do not reset during a later partition/recovery experiment.

## 5. Book through B; challenge through A

```bash
ask_office b /book '{"customer":"Alice"}'
ask_office a /book '{"customer":"Bob"}'
```

Actual Alice response:

```text
HTTP 201
{"confirmed":true,"booking":{"id":"56516fce-652f-4b0b-9c7a-cd846f4d65ae","seat":"A1","customer":"Alice","office":"a"}}
```

The office field is a: A made the decision, even though the client entered through B. Bob returned HTTP 409 with Seat already booked and the same Alice record.

## 6. Read through both entry points

```bash
ask_office a /seat
ask_office b /seat
```

Both actual responses were HTTP 200 with:

```json
{"seat":"A1","available":false,"conflict":false,"bookings":[{"id":"56516fce-652f-4b0b-9c7a-cd846f4d65ae","seat":"A1","customer":"Alice","office":"a"}]}
```

UUIDs differ on replay, but within one run both paths must return the same record. This confirms Service-based forwarding and a shared decision path. It is not replication: B consults A for each operation.

## Conclusion and next state

All requested responses were pasted and matched predictions. The source checkpoint was committed as c49c141 after verification; this note follows that commit. Kubernetes supplies discovery and workload management, while the Ruby configuration still determines the consistency strategy.

Leave both offices and service-client running, with Alice at A. No NetworkPolicy has been added in this lesson. Next we will explicitly allow client access while blocking office-to-office traffic and verify actual enforcement rather than assuming that creating a policy guarantees isolation. No additional application commit is needed merely to keep these resources running.
