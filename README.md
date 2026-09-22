# boxkit

A self-contained devcontainer for running experiments in a disposable sandbox.

A lot of stuff is preinstalled: python, uv, node, npm, and pnpm via
[proto](https://moonrepo.dev/docs/proto), plus OpenCode, Claude Code, Codex,
git, GitHub CLI, tmux, lazydocker, revdiff, and the Docker CLI (buildx +
compose).

## Getting started

1. Copy the secrets template and fill in your keys. This is **required**: the
   image build reads `secrets.env` to create the `root-dev` account, so
   `ROOT_DEV_PASSWORD` must be set (or the build fails).

   ```sh
   cp .devcontainer/secrets.env.example .devcontainer/secrets.env
   ```

2. Set the host Docker socket path in `.devcontainer/.env` (see below):

   ```sh
   # rootless host
   echo "DOCKER_HOST_SOCKET=/run/user/$(id -u)/docker.sock"
   # rootful host / Docker Desktop
   echo "DOCKER_HOST_SOCKET=/var/run/docker.sock"
   ```

3. Open the folder in a devcontainer.

Work lives in `/workspaces/dev` and `$HOME`, both on volumes that survive
rebuilds. `secrets.env` is gitignored and only ever passed in as environment
variables (and as a build secret). Tool versions are pinned in
`.devcontainer/.env`; changing them requires a rebuild.

## Container user and privilege

The container user `dev` has **no sudo**. The only sudoer is the
password-protected `root-dev` account, created at image build time from
`ROOT_DEV_PASSWORD`. Escalate with:

```sh
su - root-dev
```

The password is passed as a BuildKit build secret, so the plaintext never lands
in an image layer; only its hash is stored in `/etc/shadow`, and it is
deliberately blanked from the running container's environment. BuildKit does not
invalidate cache when a secret changes, so after editing `ROOT_DEV_PASSWORD`
rebuild **without cache** (`docker build --no-cache` / rebuild the container).

## Docker (outside of Docker)

Docker is provided by reusing the **host's** Docker daemon
(Docker-outside-of-Docker), not by running a daemon inside the container. The
host socket is bind-mounted at `/var/run/docker-host.sock` and `entrypoint.sh`
runs `socat` as root to expose it to `dev` at the standard `/var/run/docker.sock`.
No privileged container is required. Set `DOCKER_HOST_SOCKET` in
`.devcontainer/.env` to the host socket path (`/run/user/<uid>/docker.sock` for
rootless, `/var/run/docker.sock` for rootful). If the path is wrong, the
container logs a warning and `docker` is unavailable.

Caveats: containers started from inside the devcontainer are siblings on the
host daemon (not nested), they carry the host user's Docker rights, and any
bind-mount paths you pass are resolved on the **host**, not inside the
container.
