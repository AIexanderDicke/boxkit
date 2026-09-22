#!/usr/bin/env bash
# Runs as root (compose sets user: root) for the container's main process.
# Creates the unprivileged user `dev` on first start. The home dir lives on the
# dev-sandbox-home volume, so it survives rebuilds.
set -euo pipefail

if ! id -u dev >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash dev
fi

# `dev` intentionally has NO sudo. Privilege escalation goes through the
# password-protected `root-dev` account created at build time. Drop any stale
# passwordless-sudo file from an earlier image.
rm -f /etc/sudoers.d/dev

# root-dev is created at build time; its home lives on the persisted /home
# volume, so make sure it exists (e.g. on a pre-existing volume) and is private.
if id -u root-dev >/dev/null 2>&1; then
  if [ ! -d /home/root-dev ]; then
    mkdir -p /home/root-dev
    cp -a /etc/skel/. /home/root-dev/ 2>/dev/null || true
  fi
  chown -R root-dev:root-dev /home/root-dev
  chmod 0700 /home/root-dev
fi

# Heal ownership on every start: the home volume may contain files owned by an
# older uid. Top-level chown keeps VS Code server writes working; deeper drift is
# left alone (rare, and a recursive chown on every boot is expensive).
mkdir -p /home/dev && chown dev:dev /home/dev
chown dev:dev /workspaces/dev
if [ -d /opt/proto ]; then
  chown -R dev:dev /opt/proto
fi

# --- Docker-outside-of-Docker socket -----------------------------------------
# The host daemon socket is bind-mounted at /var/run/docker-host.sock. Expose it
# to `dev` through a root-owned socat proxy at the default socket path, owned by
# `dev`, so the host socket's UID/GID does not have to match a container group.
# `-S` guards against clobbering a directory Docker created when the host path
# was wrong.
if [ -S /var/run/docker-host.sock ]; then
  rm -f /var/run/docker.sock
  socat UNIX-LISTEN:/var/run/docker.sock,fork,mode=660,user=dev,group=dev \
    UNIX-CONNECT:/var/run/docker-host.sock \
    >>/tmp/docker-socket-proxy.log 2>&1 &
  echo "==> Docker socket proxy started for user dev."
else
  echo "WARNING: /var/run/docker-host.sock not found; docker will be unavailable." >&2
  echo "         Set DOCKER_HOST_SOCKET in .devcontainer/.env to the host socket." >&2
fi

exec "$@"
