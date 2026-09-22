# AGENTS.md

Environment description for agents working inside this container.

## Where you are

- A disposable sandbox container for controlled experiments. Nothing outside
  the configured volumes is yours; the container itself can be destroyed and
  rebuilt at any time without notice.
- **Workspace**: `/workspaces/dev`. This is the only project directory that
  survives container destruction/rebuild. Restarts of the container keep it
  too. It lives on the docker volume `dev-sandbox-workspace`; only that volume
  being deleted resets it.
- **Home**: `/home/dev`, persisted on the volume `dev-sandbox-home`. Git
  config, tool state, shell history and anything you put here survives
  container destruction/rebuild.
- **User**: `dev` (unprivileged, with **no sudo**). The only sudoer is the
  password-protected `root-dev` account, created at image build time; escalate
  with `su - root-dev` (you will be prompted for its password). Installing system
  packages therefore requires that escalation.
- **Docker**: the Docker CLI talks to the host daemon (Docker-outside-of-Docker).
  `docker` works as `dev`; containers you start are siblings on the host daemon.
- **Shell**: bash; VS Code terminals run inside tmux (`tmux new -A -s dev`).

## Preinstalled tooling

- **Languages/package managers**: python, pip, uv, node, npm, pnpm — all via
  [proto](https://moonrepo.dev/docs/proto) shims (`/opt/proto`). Global
  versions are pinned; shims auto-install project-pinned versions on first
  use. Pin for the current project: `proto pin <tool> <version>`. Install
  additional tools: `proto install <tool> --pin global`.
- **Git/GitHub**: `git` (identity preconfigured in `~/.gitconfig`) and `gh`
  (authenticated via `GH_TOKEN`, which is also the credential helper for
  github.com HTTPS). Committing and pushing is preconfigured and expected to
  work.
- **Utilities**: `tmux`, `lazydocker` (alias `lzd`), `revdiff` (TUI to review
  diffs/files with inline annotations; emits structured annotations on stdout
  on quit — e.g. `revdiff`, `revdiff main`, `revdiff --staged`).

## Rules

- **Secrets**: API keys and tokens are environment variables only. There is
  no secrets file in the container — do not try to find or reconstruct one.
  Use the env vars directly when a process needs them; never write them to
  files, logs, or command output.
- **Persistence**: anything you want to keep must be in `/workspaces/dev` or
  `/home/dev`. System packages, `/usr/local/bin` installs and `/opt/proto`
  changes are wiped on image rebuild — install long-lived tools via proto or
  record them somewhere persistent.
- **Non-persistent changes must be surfaced**: if you install software outside
  the persistent locations, or you conclude that this AGENTS.md (or the
  environment in general) should be updated to match reality, you MUST
  explicitly tell the user at the end of your reply — don't just do it and
  assume it will stick.

