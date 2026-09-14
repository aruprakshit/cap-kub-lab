# 09 — Diagnose the host-port path, not the Ruby application

A failed host port does not necessarily mean the app is down. This optional investigation separates Docker Desktop forwarding from the container network path.

[All lessons](README.md)

**Start:** after lesson 08, both tutorial offices are connected. This lesson is OPTIONAL and environment-specific. Do not assume your Docker version must reproduce the same error. A working host port after disconnection is a valid result on another setup.

The historical record below uses the original project, ports 4567/4568, and run-specific IP addresses. Do not paste those old network names into the isolated tutorial. Use this replay section instead.

## Controlled diagnostic replay (Ubuntu Bash)

```bash
office_b_id=$(dc ps -q office-b)
curl -v --max-time 5 http://127.0.0.1:14568/health
docker inspect "$office_b_id" --format '{{json .NetworkSettings.Networks}}'
docker network disconnect cap-kub-tutorial-coordination "$office_b_id"
```

Now compare three paths:

```bash
# Inside B, bypass all Docker host forwarding:
dc exec -T office-b ruby -rnet/http -e '
  r = Net::HTTP.get_response(URI("http://127.0.0.1:4567/health"))
  puts r.code
  puts r.body
'

# Across access-b, using a separate client:
ask_b /health

# Through the host's published port:
curl -v --max-time 5 http://127.0.0.1:14568/health

docker inspect "$office_b_id" --format '{{json .NetworkSettings.Ports}}'
docker inspect "$office_b_id" --format '{{json .NetworkSettings.Networks}}'
dc logs --tail=20 office-b
```

If internal/client paths return 200 but host access fails, the failure is outside the health route. A reset and a timeout are different TCP observations but can both reflect an unusable forwarding destination; logs are needed to establish which destination failed. If all paths fail, this is a different failure: inspect process state before applying this diagnosis.

Always restore:

```bash
docker network connect --alias office-b cap-kub-tutorial-coordination "$office_b_id"
curl -i --max-time 5 http://127.0.0.1:14568/health
```

## Obtain new logs rather than reusing old IP addresses

On Docker Desktop Windows, use Windows PowerShell (not Bash):

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Docker\log\host" -File |
  Select-String -Pattern ':14568|OutPort:14568|"out_port":14568' |
  Select-Object -Last 40
```

Read timestamps and match the CURRENT B container ID. Last 40 means enumeration order, not chronological sorting; rotated files may include older matches. Absence of a match does not prove absence of a forwarding failure. The original decisive entries are preserved below; the new IPs may differ.

## What this teaches

Publishing is a forwarding path, not just a number printed by inspect. Default-gateway choice and Desktop's published-port destination are distinct. Gateway priority did not repair the original problem. The client container isolates the application-level CAP experiment from this host-forwarding behavior.

**End state:** coordination reconnected. Continue to [lesson 10](10-booking-records-and-modes.md). The remaining section is evidence from the original investigation, not another required sequence to execute.

<details>
<summary>Original investigation, logs, and attempted fixes</summary>

## Historical investigation (original lab names and ports)

## Environment and checkpoint

Application/network checkpoint: `47c24dd06f21ff9724014de7bf7b0522fea36f3f` (`47c24dd`). Observed Docker Engine: 29.7.2; Compose: 5.5.0; Docker Desktop with Ubuntu WSL. This is a diagnosis of this observed environment, not a claim about all Docker installations.

## Initial failure

After disconnecting B from coordination:

```bash
curl -i http://localhost:4567/health
curl -i http://localhost:4568/health
```

A returned 200. B's host request returned:

```text
curl: (56) Recv failure: Connection reset by peer
```

We initially used a client on `access-b` to complete the CAP experiment. That preserved the desired client path, but it was a workaround, not a diagnosis or fix of host forwarding. The learner correctly asked us to investigate the unexplained failure.

## Recovery and initial inspection

```bash
office_b_id=$(docker compose ps -q office-b)
docker network connect --alias office-b cap-kub-lab-coordination "$office_b_id"
curl -i http://localhost:4568/health

docker compose ps
docker version --format 'Server: {{.Server.Version}}'
docker inspect "$office_b_id" --format '{{json .NetworkSettings.Ports}}'
docker inspect "$office_b_id" --format '{{json .NetworkSettings.Networks}}'
docker compose logs --tail=20 office-b
```

Health recovered to 200; both processes were running. The published configuration still showed:

```json
{"4567/tcp":[{"HostIp":"127.0.0.1","HostPort":"4568"}]}
```

Puma listened on `0.0.0.0:4567`. Early logs showed host requests from the coordination gateway, whereas temporary-client requests arrived through the access network. This was a clue, not sufficient proof of the exact failing component.

## Attempted fix: gateway priority

We set these service-level network mappings:

```yaml
# office-a
networks:
  access-a:
    gw_priority: 1
  coordination:
    gw_priority: 0

# office-b
networks:
  access-b:
    gw_priority: 1
  coordination:
    gw_priority: 0
```

These are snippets inside each service, not duplicate top-level YAML keys. Top-level network definitions stayed unchanged.

```bash
docker compose down --remove-orphans
docker compose up -d --build --force-recreate
office_b_id=$(docker compose ps -q office-b)
docker inspect "$office_b_id" --format '{{json .NetworkSettings.Networks}}'
```

An initial YAML syntax error (`mapping values are not allowed in this context`) was corrected before the successful rebuild. Inspection confirmed access priority 1 and coordination priority 0. Nevertheless, detaching coordination still reset the host connection. **Gateway priority was applied but was not a sufficient fix.** Rebuilding cleared previous in-memory bookings.

Docker documents `gw_priority` as default-gateway selection. It does not promise that Desktop will select that network's address for its published-port forwarder. See [Docker networking](https://docs.docker.com/engine/network/) and [Compose service networks](https://docs.docker.com/reference/compose-file/services/#gw_priority).

## Isolate the failing layer

With B disconnected, run:

```bash
docker inspect "$office_b_id" --format '{{json .NetworkSettings.Ports}}'
docker inspect "$office_b_id" --format '{{json .NetworkSettings.Networks}}'

docker compose exec -T office-b ruby -rnet/http -e '
  response = Net::HTTP.get_response(URI("http://127.0.0.1:4567/health"))
  puts response.code
  puts response.body
'

ask_b /health
curl -v --max-time 5 http://127.0.0.1:4568/health
```

Define `ask_b` from [lesson 08](08-network-partition.md) first.

| Check | Observed |
| --- | --- |
| Published port configuration | Still present |
| Remaining network | Only access-b, priority 1 |
| HTTP inside B | 200, status ok |
| HTTP from client on access-b | 200, status ok |
| Host TCP connection | Connected to 127.0.0.1:4568 |
| HTTP on that host connection | Reset by peer |

Reconnect and repeat the host request:

```bash
docker network connect --alias office-b cap-kub-lab-coordination "$office_b_id"
curl -v --max-time 5 http://127.0.0.1:4568/health
```

Observed 200 again, without restarting B. These results isolated host forwarding while confirming the application and surviving network worked.

## Read the Desktop forwarding logs

In Windows PowerShell, the command used was:

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Docker\log\host" -File |
  Select-String -Pattern '4568|172\.24\.0\.3|172\.22\.0\.2' |
  Select-Object -Last 40
```

The addresses came from the latest inspection; recreated networks can have different addresses. This broad search also matched unrelated historical entries. `Select-Object -Last 40` selects the last matches in enumeration order, not necessarily the chronologically newest events. We identified the relevant entries by timestamp, office B's container ID, and the forwarding destination.

Latest inspected addresses for B during this run:

| Network | B's IP |
| --- | --- |
| coordination | 172.24.0.3 |
| access-b | 172.22.0.2 |

Relevant log at 2026-09-13 13:12:47 UTC:

```text
adding ... tcp4 forward from 127.0.0.1:4568 to 172.24.0.3:4567
```

Decisive failure at 13:15:21 UTC:

```text
unable to connect on ... tcp4 forward from
127.0.0.1:4568 to 172.24.0.3:4567:
dial tcp 172.24.0.3:4567: connect: no route to host
```

Repeated forward-list entries also retained the coordination destination.

## Evidence-backed explanation

```text
Host curl -> Desktop listener :4568 -> B coordination IP :4567
                                        disconnected

Test client -> access-b -> B access IP :4567 -> Puma
                             still reachable
```

Desktop accepted the front connection but could not reach its configured destination after that endpoint was detached. This explains the TCP connection followed by reset. It did not switch the forwarder to B's surviving access address in this test. Reconnecting restored reachability.

Default-gateway preference did not change the recorded forwarding destination. The test container succeeded because it directly used the surviving access network and bypassed this host-forwarding path.

Docker Desktop's forwarding architecture is described in [its networking documentation](https://docs.docker.com/desktop/features/networking/).

## What remains unknown and what was not done

We have evidence of the unusable forwarding destination. We have not established Desktop's internal address-selection algorithm, a specific upstream bug/fixed version, or a supported setting that repairs this behavior. No Docker reinstall, daemon change, or firewall change was made.

A suggested alternative is a proxy attached only to access-b, with the host port published on that stable proxy. That is an architectural workaround and has not been implemented or tested here. The completed CAP experiment uses the verified temporary-client path.

Do not generalize this Desktop behavior into a rule that all Docker network disconnections break published ports. This note records one reproducible environment-specific failure and its evidence.

</details>
