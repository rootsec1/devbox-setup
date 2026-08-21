# Contributing

Thanks for helping make devbox-setup better.

## Development

Keep changes small, idempotent, and compatible with both supported Ubuntu LTS
releases. Do not run provisioning roles against your workstation.

Run the containerized checks before opening a pull request:

```bash
docker compose --profile test run --build --rm static
docker compose --profile test up --build \
  --abort-on-container-exit --exit-code-from e2e e2e
docker compose --profile test down --volumes --remove-orphans
```

Update the README, schema, example profile, and tests together when changing a
public configuration field. Never commit credentials or real SSH keys.

## Pull requests

- Explain the user-facing problem and behavior change.
- Add failure-path coverage for provisioning changes.
- Preserve user files and secure SSH defaults.
- Confirm the second Ansible run reports no changes.
