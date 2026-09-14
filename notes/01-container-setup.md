# 01 — A Ruby application without installing Ruby on Ubuntu

Ruby and its gems live in the container. Your machine only needs the tools to build and run it; the committed lockfile keeps dependency versions consistent.

[All lessons](README.md)

**Start:** complete [start here](00-start-here.md). Run from the tutorial worktree in Bash. This lesson explains the build inputs; lesson 02 starts the server.

## Predict

Where will Ruby and the installed gems live? In the image/container. Where does the source live? In your worktree and, after COPY, in the image. These are different filesystem locations.

## 1. Check the runtime tools

```bash
docker info --format '{{.OSType}}'
docker compose version
git --version
curl --version
```

Require `linux` from Docker and successful version output. If Docker fails, fix Desktop/WSL integration first. The original environment reported Compose 5.5.0. k3d 5.9.0 and kubectl 1.36.1 were available but are not needed for these experiments.

## 2. Read the actual first checkpoint

```bash
git show --no-patch --oneline HEAD
cat Gemfile
cat Dockerfile
cat compose.yml
cat app.rb
```

HEAD should be `b5086f1` — Add containerized Sinatra ticket booking service with Bundler and Docker Compose. This source has a single service named `office` and a single in-memory `BOOKING`. Do not use the latest app.rb to replay this stage.

The Gemfile pins Sinatra 4.1.1, Puma 6.6.0, and rackup 2.2.1. Sinatra defines routes; Puma handles HTTP requests; Rack connects them. The Dockerfile uses `ruby:4.0.6` and:

```dockerfile
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local frozen true \
    && bundle install
COPY app.rb .
EXPOSE 4567
CMD ["bundle", "exec", "ruby", "app.rb"]
```

`frozen` requires Gemfile and lockfile to agree. `bundle exec` uses the selected bundle. Dependencies are copied before app.rb so code-only edits can reuse the installed-gem layer. COPY is not a live mount: restart alone does not incorporate later source edits.

<details>
<summary>3. Understand the lockfile (do not regenerate on normal replay)</summary>

## 3. Understand the lockfile (do not regenerate on normal replay)

```bash
cat Gemfile.lock
```

It records the resolved direct and transitive dependencies. Direct `gem install ... -v ...` instructions were our early teaching shortcut, replaced by Bundler for reproducibility. Both Gemfile and lockfile belong in Git.

For a project being authored from scratch, after manually creating a Gemfile, the original lock-generation command was:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e BUNDLE_APP_CONFIG=/tmp/bundle \
  -v "$PWD:/app" \
  -w /app \
  ruby:4.0.6 \
  bundle lock
```

This is an explanation of project creation, not a required step when replaying the committed lockfile.

| Option | Meaning and reason |
| --- | --- |
| --rm | Remove the temporary container after it exits; keep mounted files |
| --user | Use your Ubuntu numeric user/group, so generated files are not root-owned |
| HOME=/tmp | Supply a writable home directory inside the temporary container |
| BUNDLE_APP_CONFIG=/tmp/bundle | Keep Bundler's configuration in that temporary container |
| -v "$PWD:/app" | Mount the current host directory into /app; the lockfile survives there |
| -w /app | Run where Gemfile is located |
| bundle lock | Resolve/write dependencies without installing the app's gems |

`$(id -u)` and `$PWD` are expanded by Ubuntu before Docker runs. The runtime installs the gems later during image build.

</details>

## 4. Check port publishing before startup

```bash
dc config
```

The historical compose.yml publishes `4567:4567`, on all host interfaces by default. Our tutorial overlay replaces it with `127.0.0.1:14567:4567`. The earlier chat suggested a loopback mapping; that was not what the first commit contained.

Ruby listens on `0.0.0.0:4567` INSIDE the container so forwarded traffic can reach it. Docker publishes host port 14567 through the overlay. EXPOSE alone does not publish a port.

**Checkpoint:** source at b5086f1, Docker reachable, effective config contains only the tutorial host port. No server is required yet. Next: [one office](02-one-office.md).

---

Next: [02 — One office accepts one booking](02-one-office.md).
