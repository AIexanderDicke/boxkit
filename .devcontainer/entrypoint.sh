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

# Heal ownership on every start: the home volume may contain files owned by an
# older uid (e.g. dev was uid 1001 before the slim base pre-created it as
# 1000). Top-level chown keeps VS Code server writes working; deeper drift is
# left alone (rare, and a recursive chown on every boot is expensive).
mkdir -p /home/dev && chown dev:dev /home/dev
chown dev:dev /workspaces/dev
if [ -d /opt/proto ]; then
  chown -R dev:dev /opt/proto
fi

exec "$@"
