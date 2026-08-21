#!/usr/bin/env bash
set -Eeuo pipefail

required=(DEVBOX_COMMAND DEVBOX_HOST DEVBOX_USER DEVBOX_PORT DEVBOX_AUTH_MODE)
for variable in "${required[@]}"; do
  [[ -n "${!variable:-}" ]] || { printf 'controller: %s is required\n' "$variable" >&2; exit 2; }
done

case "$DEVBOX_COMMAND" in
  setup|doctor) ;;
  *) printf 'controller: unsupported command: %s\n' "$DEVBOX_COMMAND" >&2; exit 2 ;;
esac

python3 /workspace/tools/validate_config.py /run/devbox/config.yml

export ANSIBLE_CONFIG=/workspace/ansible/ansible.cfg
export ANSIBLE_HOST_KEY_CHECKING=True
export ANSIBLE_SSH_ARGS="-o UserKnownHostsFile=/run/devbox/known_hosts -o StrictHostKeyChecking=yes -o IdentitiesOnly=yes"

ssh_options=(
  --inventory "${DEVBOX_HOST},"
  --user "$DEVBOX_USER"
  --extra-vars "ansible_port=${DEVBOX_PORT}"
  --extra-vars @/run/devbox/config.yml
)

case "$DEVBOX_AUTH_MODE" in
  identity)
    ssh_options+=(--private-key /run/devbox/identity)
    ;;
  agent)
    export SSH_AUTH_SOCK=/run/devbox/agent
    export ANSIBLE_SSH_ARGS="-o UserKnownHostsFile=/run/devbox/known_hosts -o StrictHostKeyChecking=yes"
    ;;
  *)
    printf 'controller: unsupported authentication mode\n' >&2
    exit 2
    ;;
esac

playbook="/workspace/ansible/${DEVBOX_COMMAND}.yml"

printf '==> %s %s@%s:%s\n' "$DEVBOX_COMMAND" "$DEVBOX_USER" "$DEVBOX_HOST" "$DEVBOX_PORT"
if ! ansible-playbook "$playbook" "${ssh_options[@]}"; then
  printf '\nProvisioning failed. Fix the reported prerequisite and rerun the same command; all tasks are idempotent.\n' >&2
  exit 1
fi
