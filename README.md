# boxkit

A self-contained devcontainer for running experiments in a disposable sandbox.

A lot of stuff is preinstalled: python, uv, node, npm, and pnpm via
[proto](https://moonrepo.dev/docs/proto), plus OpenCode, Claude Code, Codex,
git, GitHub CLI, tmux, lazydocker, and revdiff.

## Getting started

1. Copy the secrets template and fill in your keys:

   ```sh
   cp .devcontainer/secrets.env.example .devcontainer/secrets.env
   ```

2. Open the folder in a devcontainer.

Work lives in `/workspaces/dev` and `$HOME`, both on volumes that survive
rebuilds. `secrets.env` is gitignored and only ever passed in as environment
variables. Tool versions are pinned in `.devcontainer/.env`; changing them
requires a rebuild.
