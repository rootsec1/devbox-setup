# devbox-setup

[![CI](https://github.com/rootsec1/devbox-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/rootsec1/devbox-setup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Turn a fresh Ubuntu server into a clean, AI-ready development box with one
command. The provisioner runs from Docker, connects over SSH, and leaves your
existing dotfiles and credentials alone.

## What you get

- Git, Git LFS, ripgrep, fd, fzf, bat, jq, tmux, zsh, ShellCheck, and build tools
- Docker Engine, Buildx, and Compose
- GitHub CLI
- Node.js 24 LTS, Python 3.14, and Go 1.26 through mise
- OpenAI Codex CLI, installed but not authenticated
- An idempotent setup you can safely rerun

Supported targets are Ubuntu 22.04 and 24.04 on amd64. The SSH user must have
key-based access and passwordless sudo.

## Quick start

Requirements on your workstation:

- Docker Engine with Compose v2
- An SSH private key or a running SSH agent
- The target's host key in `~/.ssh/known_hosts`

```bash
git clone https://github.com/rootsec1/devbox-setup.git
cd devbox-setup

ssh-keyscan -H devbox.example.com >> ~/.ssh/known_hosts

./bin/devbox setup \
  --host devbox.example.com \
  --user ubuntu \
  --identity ~/.ssh/id_ed25519
```

Validate the finished machine:

```bash
./bin/devbox doctor \
  --host devbox.example.com \
  --user ubuntu \
  --identity ~/.ssh/id_ed25519
```

If your key is already loaded, omit `--identity`; the CLI forwards
`SSH_AUTH_SOCK`. Host-key verification cannot be disabled.

## Configure the profile

Copy and edit [`devbox.yml`](devbox.yml). It is validated before any SSH
connection is attempted.

```yaml
workspace_dir: "~/workspace"

runtimes:
  node: {enabled: true, version: "24"}
  python: {enabled: true, version: "3.14"}
  go: {enabled: true, version: "1.26"}

features:
  docker: true
  github_cli: true
  codex: {enabled: true, version: "0.149.0"}

extra_packages: []
```

Pass a custom profile with `--config path/to/devbox.yml`. Codex depends on the
configured Node runtime. Runtime values select a major release line; mise
resolves the available patch release during initial installation. Codex uses an
exact package version for repeatable installs.

## Sign in to Codex

Provisioning never copies an API key, ChatGPT session, or `~/.codex/auth.json`.
On a remote/headless devbox, use the device-code flow:

```bash
codex login --device-auth
```

See the [official authentication documentation](https://learn.chatgpt.com/docs/auth)
for API-key and fallback login methods.

## Test

Nothing is installed on the test host. Static checks and the live Ubuntu matrix
run entirely through Docker Compose:

```bash
docker compose --profile test run --build --rm static

docker compose --profile test up --build \
  --abort-on-container-exit --exit-code-from e2e e2e

docker compose --profile test down --volumes --remove-orphans
```

The E2E suite provisions two privileged disposable targets through real SSH,
runs `docker run hello-world`, executes the doctor playbook, checks failure
paths, and requires a second provisioning pass to report `changed=0`.

## Operations

Provisioning is additive and safe to rerun after a network or package-manager
failure. Version changes are made in `devbox.yml` and applied with the same
`setup` command.

There is intentionally no destructive uninstall command. To remove the setup,
delete the marked `DEVBOX-SETUP MANAGED BLOCK` sections from shell files,
remove `~/.config/mise`, `~/.local/share/mise`, and `~/workspace` if unwanted,
then uninstall system packages with the host's package manager. Review data
before deleting user directories.

## Project

Read [the architecture](docs/architecture.md), [contribution guide](CONTRIBUTING.md),
and [security policy](SECURITY.md). Released under the [MIT License](LICENSE).
