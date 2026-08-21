# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub's security advisory
flow. Do not open a public issue for credential exposure, command injection,
privilege escalation, or SSH host-verification problems.

## Security model

- SSH host-key verification is mandatory.
- Remote access uses a selected identity file or forwarded agent socket.
- The target must explicitly grant passwordless sudo to the SSH user.
- Secrets are never accepted in `devbox.yml` or copied to the target.
- User shell files are modified only inside a labeled managed block.
- Containerized tests use generated, disposable SSH keys.

Only the latest release on the `main` branch receives security fixes.
