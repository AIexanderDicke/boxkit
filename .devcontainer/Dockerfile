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

# --- Dev user (uid 1000, passwordless sudo) + workspace dir --------------------
# /home is masked by the dev-sandbox-home volume at runtime; entrypoint.sh
# re-creates the home dir there on first start.
RUN userdel --remove ubuntu 2>/dev/null || true \
  && useradd --uid 1000 --create-home --shell /bin/bash dev \
  && printf 'dev ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/dev \
  && chmod 0440 /etc/sudoers.d/dev \
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

COPY .devcontainer/entrypoint.sh /usr/local/bin/dev-entrypoint.sh
RUN chmod +x /usr/local/bin/dev-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]
