FROM mcr.microsoft.com/devcontainers/base:1-bookworm

# Tool versions, single source of truth: .devcontainer/.env
ARG NODE_VERSION=22
ARG PNPM_VERSION=latest
ARG PYTHON_VERSION=3.13
ARG UV_VERSION=latest
ARG CODEX_VERSION=latest
ARG OPENCODE_VERSION=latest
ARG LAZYDOCKER_VERSION=0.25.2
ARG REVDIFF_VERSION=latest

# The upstream image may carry an obsolete Yarn apt source that breaks apt-get update.
RUN rm -f /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn.sources

# Pre-create the workspace dir so the named volume starts out dev-writable.
RUN mkdir -p /workspaces/dev && chown vscode:vscode /workspaces/dev

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
  && chown -R vscode:vscode "$PROTO_HOME"

# --- tmux + lazydocker --------------------------------------------------------
# tmux is the default terminal in VS Code; `lzd` runs lazydocker.
RUN apt-get update \
  && apt-get install -y --no-install-recommends tmux \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" \
       | tar -xz -C /usr/local/bin lazydocker

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

# `lzd` shortcut for lazydocker, sourced by every interactive bash shell.
RUN printf '\nalias lzd="lazydocker"\n' >> /etc/bash.bashrc

# npm-based coding agents installed into /usr/local (proto rewrites npm's
# global prefix, so the claude-code devcontainer feature cannot be used).
RUN npm_config_prefix=/usr/local npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code \
  && npm_config_prefix=/usr/local npm install -g --allow-scripts=@openai/codex --allow-scripts=opencode-ai "@openai/codex@${CODEX_VERSION}" "opencode-ai@${OPENCODE_VERSION}"

COPY .devcontainer/entrypoint.sh /usr/local/bin/dev-entrypoint.sh
RUN chmod +x /usr/local/bin/dev-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]
