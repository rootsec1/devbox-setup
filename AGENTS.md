# Agent guide

## Repository map

- `bin/devbox` is the only host-side interface and only invokes Docker Compose.
- `ansible/roles/devbox` owns remote state.
- `tools/config.schema.json` is authoritative for the public profile.
- `tests/e2e.sh` provisions disposable targets through real SSH.

## Rules

- Never execute setup playbooks against the development host.
- Keep tasks idempotent and preserve unmanaged user content.
- Do not weaken SSH host-key checking or add credential fields.
- Update schema, defaults, example configuration, docs, and tests together.
- Use Docker Compose for all checks.
