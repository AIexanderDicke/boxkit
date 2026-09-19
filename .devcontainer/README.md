# boxkit

A self-contained devcontainer that provides a controlled sandbox for
experiments: everything preinstalled, nothing to set up inside the container.

## What it provides

- **Toolchain**: python, pip, uv, node (incl. npm), pnpm — managed by
  [proto](https://moonrepo.dev/docs/proto), pinned at build time from
  `.devcontainer/.env`. Shims auto-install versions declared by projects
  (`.prototools`, `.nvmrc`, `package.json` `devEngines`); pin per project with
  `proto pin <tool> <version>`, add tools with `proto install <tool> --pin global`.
- **Coding agents**: OpenCode, Claude Code, Codex (versions also set in `.env`).
- **CLI basics**: git, GitHub CLI (authed via `GH_TOKEN`), tmux (default VS Code
  terminal), lazydocker (`lzd`), revdiff (diff-review TUI).
- **Persistence**: the repo is seeded into the `dev-sandbox-workspace` volume
  (`/workspaces/dev`); home lives on `dev-sandbox-home`. Both survive
  recreates; `docker volume rm dev-sandbox-workspace` / `dev-sandbox-home`
  resets them.
- **User**: runs as unprivileged `dev` with passwordless sudo — full install
  rights inside the container.

## Setup

1. `cp .devcontainer/secrets.env.example .devcontainer/secrets.env` and add
   keys (`OPENCODE_API_KEY`, `GH_TOKEN`, `GITHUB_USER`, `GIT_USER_NAME`,
   `GIT_USER_EMAIL`). `secrets.env` is gitignored and only enters the container
   as environment variables.
2. Harness-neutral agent config lives in `.devcontainer/config/` —
   `AGENTS.md` (the standard instructions file most coding harnesses read) plus
   a `skills/` placeholder. It is copied into the workspace root on every
   create (existing files are not overwritten). Harnesses keep their own state
   (`~/.claude`, `~/.config/opencode`, …) on the persisted home volume.
3. Reopen in container. Tool versions changed in `.env` require a rebuild.

## Secrets

`secrets.env` never lands on the container filesystem: the container receives
its values only as environment variables (compose `env_file`), the file is
masked on the staging mount, and `post-create.sh` deletes any copy from the
workspace volume.
