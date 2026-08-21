# Architecture

```text
./bin/devbox
    |
    v
Docker Compose controller (Ansible + validators)
    |
    | SSH with strict host-key checking
    v
Ubuntu devbox (idempotent role)
```

The host wrapper validates local paths and passes only the selected profile,
known-hosts file, and SSH identity or agent socket into the controller. The
controller validates configuration before opening a network connection and
then runs either the setup or doctor playbook.

The role separates preflight, system packages, Docker, GitHub CLI, runtimes,
Codex, and shell integration. System changes use apt and sudo. Runtimes and
Codex live in the remote user's home through mise and npm. Shell integration is
a labeled block so unrelated dotfile content survives upgrades.

The E2E topology mirrors production: one controller connects to two clean
Ubuntu targets over SSH. Test targets are privileged only so the freshly
installed Docker daemon can start and run a real workload inside them.
