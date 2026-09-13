# Source this file from Bash after setting TUTORIAL_SOURCE and TUTORIAL_WORK.
# This file defines helpers only. Sourcing it does not start or change containers.
: "${TUTORIAL_SOURCE:?Set TUTORIAL_SOURCE to the original repository directory}"
: "${TUTORIAL_WORK:?Set TUTORIAL_WORK to the tutorial worktree directory}"

dc() {
  if [ "$(pwd -P)" != "$(cd "$TUTORIAL_WORK" && pwd -P)" ]; then
    echo "Run from the tutorial worktree: cd $TUTORIAL_WORK" >&2
    return 1
  fi
  local checkpoint
  local -a overlays
  checkpoint=$(git rev-parse --short=7 HEAD) || return
  case "$checkpoint" in
    b5086f1) overlays=(-f "$TUTORIAL_SOURCE/notes/fixtures/single.yml") ;;
    0aedb7a|981fa2e) overlays=(-f "$TUTORIAL_SOURCE/notes/fixtures/two.yml") ;;
    47c24dd) overlays=(-f "$TUTORIAL_SOURCE/notes/fixtures/two.yml" -f "$TUTORIAL_SOURCE/notes/fixtures/networks.yml") ;;
    b2425cb|e4b07a5) overlays=(-f "$TUTORIAL_SOURCE/notes/fixtures/two.yml" -f "$TUTORIAL_SOURCE/notes/fixtures/networks.yml" -f "$TUTORIAL_SOURCE/notes/fixtures/mode.yml") ;;
    *) echo "Unsupported tutorial checkpoint: $checkpoint" >&2; return 1 ;;
  esac
  docker compose -p cap-kub-tutorial -f compose.yml "${overlays[@]}" "$@"
}

wait_for_offices() {
  local ports port attempt ready
  ports="14567"
  if dc config --services | grep -qx office-b; then ports="$ports 14568"; fi
  for port in $ports; do
    ready=0
    for attempt in {1..30}; do
      if curl --silent --fail --max-time 2 "http://127.0.0.1:$port/health" >/dev/null; then
        ready=1; break
      fi
      sleep 1
    done
    if [ "$ready" != 1 ]; then
      echo "Office on $port is not ready. Run: dc logs --tail=40" >&2
      return 1
    fi
  done
  echo "All expected offices answer health checks."
}

ask_b() {
  local container_id image_id
  container_id=$(dc ps -q office-b) || return
  if [ -z "$container_id" ]; then echo "Start office-b first." >&2; return 1; fi
  image_id=$(docker inspect --format '{{.Image}}' "$container_id") || return
  docker run --rm --network cap-kub-tutorial_access-b "$image_id" \
    ruby -rnet/http -e '
      uri = URI("http://office-b:4567#{ARGV.fetch(0)}")
      req = ARGV[1] ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      if ARGV[1]
        req["Content-Type"] = "application/json"
        req.body = ARGV[1]
      end
      response = Net::HTTP.start(uri.host, uri.port, nil,
        open_timeout: 2, read_timeout: 10) { |http| http.request(req) }
      puts "HTTP #{response.code}"
      puts response.body
    ' "$@"
}
