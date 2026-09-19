#!/usr/bin/env bash
# Runs as the remote user (dev) after the container is created.
set -euo pipefail

WORKSPACE="/workspaces/dev"
SOURCE_DIR="/workspace-source"
# Overlay the config from the repo's staging mount, NOT from the workspace
# copy: the workspace copy was seeded at first create, so newly added config
# files would never reach an already-seeded volume.
CONFIG_DIR="$SOURCE_DIR/.devcontainer/config"

# --- Seed the workspace volume from the repo -----------------------------------
# The repo is bind-mounted read-only at /workspace-source. If the workspace
# volume is still empty (first create), copy the repo into it. Existing files
# are NOT overwritten, so user work survives recreates.
if [ -d "$SOURCE_DIR" ]; then
  if [ -z "$(ls -A "$WORKSPACE")" ]; then
    cp -rn "$SOURCE_DIR"/. "$WORKSPACE"/
    echo "==> Seeded /workspaces/dev from repository."
  else
    echo "==> Workspace volume already seeded; keeping existing files."
  fi
else
  echo "WARNING: $SOURCE_DIR not found; skipping workspace seeding." >&2
fi

# --- Secrets never enter the container filesystem -----------------------------
# The container receives secrets as env vars (secrets.env -> compose env_file).
# The file itself must not exist anywhere an agent can read it: delete any copy
# that came along with the workspace seed (also cleans up volumes seeded before
# this rule existed). docker-compose.yml additionally masks the path on the
# staging mount, so it cannot be copied back in.
if [ -f "$WORKSPACE/.devcontainer/secrets.env" ]; then
  rm -f "$WORKSPACE/.devcontainer/secrets.env"
  echo "==> Removed workspace copy of secrets.env (secrets come from env vars only)."
fi

# --- Seed OpenCode auth from secrets.env -------------------------------------
# secrets.env is gitignored; OPENCODE_API_KEY inside it is written into
# ~/.local/share/opencode/auth.json so `opencode` is authenticated on boot.
# Adjust "provider" if you use a different gateway (e.g. openrouter).
if [ -n "${OPENCODE_API_KEY:-}" ]; then
  mkdir -p "$HOME/.local/share/opencode"
  cat > "$HOME/.local/share/opencode/auth.json" <<EOF
{
  "provider": {
    "api_key": "${OPENCODE_API_KEY}",
    "type": "api"
  }
}
EOF
  echo "==> Seeded OpenCode auth from secrets.env."
else
  echo "WARNING: OPENCODE_API_KEY not set; OpenCode will not be authenticated." >&2
  echo "         Add it to .devcontainer/secrets.env and re-run: bash .devcontainer/post-create.sh" >&2
fi

# --- Overlay config dir into the workspace -----------------------------------
# .devcontainer/config holds harness-neutral agent config (AGENTS.md, skills,
# ...). Copy it to the workspace root on every create so updates propagate.
# Existing files are NOT overwritten.
if [ -d "$CONFIG_DIR" ]; then
  cp -rn "$CONFIG_DIR"/. "$WORKSPACE"/ 2>/dev/null || true
  echo "==> Copied .devcontainer/config into workspace (existing files kept)."
fi

# --- Git & GitHub ---------------------------------------------------------------
# Git identity is written into ~/.gitconfig on the dev-sandbox-home volume, so it
# persists across recreates. Re-running is idempotent.
if [ -n "${GIT_USER_NAME:-}" ] && [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.name "${GIT_USER_NAME}"
  git config --global user.email "${GIT_USER_EMAIL}"
  echo "==> Wrote git identity to ~/.gitconfig."
else
  echo "WARNING: GIT_USER_NAME/GIT_USER_EMAIL not set; git commits will be unconfigured." >&2
  echo "         Add them to .devcontainer/secrets.env and re-run: bash .devcontainer/post-create.sh" >&2
fi

# GitHub access: gh reads GH_TOKEN from the environment directly (it is provided
# by secrets.env via docker compose env_file, so it survives container restarts).
# `gh auth setup-git` additionally registers gh as the credential helper for
# github.com, so `git push/pull` over HTTPS works with the same token.
if [ -n "${GH_TOKEN:-}" ]; then
  gh auth setup-git
  echo "==> gh credential helper configured for github.com."
  if [ -n "${GITHUB_USER:-}" ]; then
    echo "     GitHub user: ${GITHUB_USER}"
  fi
else
  echo "WARNING: GH_TOKEN not set; gh CLI and git push to GitHub will not be authenticated." >&2
  echo "         Add it to .devcontainer/secrets.env and re-run: bash .devcontainer/post-create.sh" >&2
fi

echo "==> Setup complete."
