#!/usr/bin/env bash
# Runs as root (compose sets user: root) for the container's main process.
# Creates the unprivileged user `dev` on first start. The home dir lives on the
# dev-sandbox-home volume, so it survives rebuilds.
set -euo pipefail

if ! id -u dev >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash dev
  printf 'dev ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/dev
  chmod 0440 /etc/sudoers.d/dev
fi

# Make sure the user's home and everything they need to write to is owned by
# them (npm -g installs land in /opt/proto, npm writes ~/.local, ...).
if [ ! -d /home/dev ]; then
  mkdir -p /home/dev && chown dev:dev /home/dev
fi
chown dev:dev /workspaces/dev
if [ -d /opt/proto ]; then
  chown -R dev:dev /opt/proto
fi

exec "$@"
