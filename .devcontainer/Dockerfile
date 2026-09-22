# syntax=docker/dockerfile:1
FROM ubuntu:24.04

# Tool versions, single source of truth: .devcontainer/.env
ARG NODE_VERSION=22
ARG PNPM_VERSION=latest
ARG PYTHON_VERSION=3.13
ARG UV_VERSION=latest
ARG CODEX_VERSION=latest
ARG OPENCODE_VERSION=latest
ARG LAZYDOCKER_VERSION=0.25.2
ARG REVDIFF_VERSION=latest

# --- System packages (least volatile layer) -----------------------------------
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       bash-completion ca-certificates curl git less procps sudo tmux xz-utils \
  && rm -rf /var/lib/apt/lists/*

# --- Docker CLI (Docker-outside-of-Docker) + socat -----------------------------
# The CLI talks to the host daemon socket forwarded by docker-compose.yml (DooD,
# no privileged container). entrypoint.sh runs socat as root to expose that
# socket to the unprivileged `dev` user, so the host socket's UID/GID does not
# have to match anything inside the container.
RUN install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends socat docker-ce-cli docker-buildx-plugin docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

# --- Dev user (uid 1000, NO sudo) + workspace dir ------------------------------
# /home is masked by the dev-sandbox-home volume at runtime; entrypoint.sh
# re-creates the home dir there on first start. `dev` deliberately has NO sudo:
# privilege escalation goes through the password-protected `root-dev` account
# created below.
RUN userdel --remove ubuntu 2>/dev/null || true \
  && useradd --uid 1000 --create-home --shell /bin/bash dev \
  && mkdir -p /workspaces/dev \
  && chown dev:dev /workspaces/dev

# --- proto (moonrepo) toolchain manager --------------------------------------
# Manages node, python, etc. with per-project version detection (.prototools,
# .nvmrc, ...). Pinned globally at build time; shims auto-install missing
# versions declared by a project (see [settings].auto-install below).
ENV PROTO_HOME=/opt/proto
ENV PATH="${PROTO_HOME}/shims:${PROTO_HOME}/bin:${PATH}"

RUN curl -fsSL https://moonrepo.dev/install/proto.sh | env PROTO_HOME=/opt/proto bash -s -- --yes --no-profile \
  && "$PROTO_HOME/bin/proto" install "node" "${NODE_VERSION}" --pin global \
  && "$PROTO_HOME/bin/proto" install npm --pin global \
  && "$PROTO_HOME/bin/proto" install "pnpm" "${PNPM_VERSION}" --pin global \
  && "$PROTO_HOME/bin/proto" install "python" "${PYTHON_VERSION}" --pin global \
  && "$PROTO_HOME/bin/proto" install "uv" "${UV_VERSION}" --pin global \
  && printf '[settings]\nauto-install = true\ntelemetry = false\n' >> "$PROTO_HOME/.prototools" \
  && rm -rf "$PROTO_HOME/cache" "$PROTO_HOME/temp" \
  && chown -R dev:dev "$PROTO_HOME"

# --- lazydocker + shell config --------------------------------------------------
# profile.d keeps proto shims on PATH for sudo/login shells (sudo's secure_path
# resets the container PATH).
RUN curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" \
     | tar -xz -C /usr/local/bin lazydocker \
  && printf 'export PATH="/opt/proto/shims:/opt/proto/bin:$PATH"\n' > /etc/profile.d/proto.sh \
  && printf '\nalias lzd="lazydocker"\n' >> /etc/bash.bashrc

# --- revdiff (diff-review TUI, umputun/revdiff) --------------------------------
# "latest" resolves the tag at build time via the GitHub API; bash completions
# from the tarball are installed into /etc/bash_completion.d.
RUN if [ "${REVDIFF_VERSION}" = "latest" ]; then \
      REVDIFF_VERSION="$(curl -fsSL https://api.github.com/repos/umputun/revdiff/releases/latest \
        | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p')" \
      && test -n "${REVDIFF_VERSION}"; \
    fi \
  && VER="${REVDIFF_VERSION#v}" \
  && curl -fsSL "https://github.com/umputun/revdiff/releases/download/v${VER}/revdiff_${VER}_linux_amd64.tar.gz" \
       | tar -xz -C /tmp \
  && mv /tmp/revdiff /usr/local/bin/revdiff \
  && mkdir -p /etc/bash_completion.d \
  && mv /tmp/completions/revdiff.bash /etc/bash_completion.d/revdiff \
  && rm -rf /tmp/completions

# --- Coding agents -------------------------------------------------------------
# npm-based agents installed into /usr/local (proto rewrites npm's global
# prefix, so the claude-code devcontainer feature cannot be used). Separate
# layers so a bump of CODEX/OPENCODE does not rebuild the claude-code layer.
RUN npm_config_prefix=/usr/local npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code

RUN npm_config_prefix=/usr/local npm install -g --allow-scripts=@openai/codex --allow-scripts=opencode-ai \
      "@openai/codex@${CODEX_VERSION}" "opencode-ai@${OPENCODE_VERSION}"

# --- Privileged admin account ------------------------------------------------
# `dev` is deliberately left WITHOUT sudo. `root-dev` is the only sudoer and is
# password-protected. The password is read from the BuildKit secret granted in
# docker-compose.yml (from the untracked .devcontainer/secrets.env), so the
# plaintext never lands in an image layer — only the hash in /etc/shadow.
# Created in the system UID range so it can never collide with `dev` (uid 1000)
# nor with the host-UID remap the devcontainer CLI applies to the remote user.
# NOTE: BuildKit does not invalidate the cache when a secret's contents change,
# so after editing ROOT_DEV_PASSWORD you must rebuild without cache.
RUN --mount=type=secret,id=secrets_env,required=true \
  set -eu; \
  ROOT_DEV_PASSWORD="$(sed -n 's/^ROOT_DEV_PASSWORD=//p' /run/secrets/secrets_env 2>/dev/null | grep -v '^$' | tail -n1)"; \
  if [ -z "${ROOT_DEV_PASSWORD:-}" ]; then \
    echo "ERROR: set ROOT_DEV_PASSWORD in .devcontainer/secrets.env before building." >&2; \
    exit 1; \
  fi; \
  useradd --system --create-home --shell /bin/bash --home-dir /home/root-dev root-dev; \
  printf 'root-dev:%s\n' "$ROOT_DEV_PASSWORD" | chpasswd; \
  usermod -aG sudo root-dev

COPY .devcontainer/entrypoint.sh /usr/local/bin/dev-entrypoint.sh
RUN chmod +x /usr/local/bin/dev-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]
