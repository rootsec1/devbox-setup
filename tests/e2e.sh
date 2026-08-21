#!/usr/bin/env bash
set -Eeuo pipefail
cd /workspace

export ANSIBLE_CONFIG=/workspace/ansible/ansible.cfg
export ANSIBLE_HOST_KEY_CHECKING=True
readonly key=/run/test-keys/id_ed25519
readonly known_hosts=/tmp/devbox-known-hosts
readonly ssh_args="-o UserKnownHostsFile=${known_hosts} -o StrictHostKeyChecking=yes -o IdentitiesOnly=yes"

wait_for_ssh() {
  local host="$1"
  local port="$2"
  for _ in $(seq 1 60); do
    if ssh-keyscan -T 2 -p "$port" -H "$host" >>"$known_hosts" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "SSH did not become ready on ${host}:${port}" >&2
  return 1
}

run_playbook() {
  local playbook="$1"
  local host="$2"
  local port="$3"
  shift 3
  ANSIBLE_SSH_ARGS="$ssh_args" ansible-playbook \
    "$playbook" \
    --inventory "${host}," \
    --user devbox \
    --private-key "$key" \
    --extra-vars "ansible_port=${port}" \
    --extra-vars @/workspace/devbox.yml \
    "$@"
}

: >"$known_hosts"
chmod 600 "$known_hosts"
wait_for_ssh 127.0.0.1 2204
wait_for_ssh 127.0.0.1 2404
wait_for_ssh 127.0.0.1 2405

cat >/tmp/minimal.yml <<'YAML'
---
workspace_dir: "~/workspace"
runtimes:
  node: {enabled: false, version: "24"}
  python: {enabled: false, version: "3.14"}
  go: {enabled: false, version: "1.26"}
features:
  docker: false
  github_cli: false
  codex: {enabled: false, version: "0.149.0"}
extra_packages: []
YAML
python3 tools/validate_config.py /tmp/minimal.yml

echo "==> Negative preflight: unavailable SSH"
if ANSIBLE_SSH_ARGS="$ssh_args" ansible all -i '127.0.0.1,' -u devbox \
  -e ansible_port=1 --private-key "$key" -m ansible.builtin.ping; then
  echo "unavailable SSH target unexpectedly succeeded" >&2
  exit 1
fi

echo "==> Negative preflight: passwordless sudo"
if ANSIBLE_SSH_ARGS="$ssh_args" ansible-playbook ansible/setup.yml \
  -i '127.0.0.1,' -u nosudo --private-key "$key" \
  -e ansible_port=2404 -e @devbox.yml --tags preflight; then
  echo "user without sudo unexpectedly passed preflight" >&2
  exit 1
fi

echo "==> Negative preflight: unsupported platform"
if run_playbook ansible/setup.yml 127.0.0.1 2404 --tags preflight \
  --extra-vars ansible_distribution=Debian; then
  echo "unsupported distribution unexpectedly passed preflight" >&2
  exit 1
fi

echo "==> Negative preflight: unsupported architecture"
if run_playbook ansible/setup.yml 127.0.0.1 2404 --tags preflight \
  --extra-vars ansible_architecture=aarch64; then
  echo "unsupported architecture unexpectedly passed preflight" >&2
  exit 1
fi

echo "==> Disabled feature profile"
ANSIBLE_SSH_ARGS="$ssh_args" ansible-playbook ansible/setup.yml \
  -i '127.0.0.1,' -u devbox --private-key "$key" \
  -e ansible_port=2405 -e @/tmp/minimal.yml
ANSIBLE_SSH_ARGS="$ssh_args" ansible-playbook ansible/doctor.yml \
  -i '127.0.0.1,' -u devbox --private-key "$key" \
  -e ansible_port=2405 -e @/tmp/minimal.yml
ssh -p 2405 -i "$key" -o UserKnownHostsFile="$known_hosts" -o StrictHostKeyChecking=yes \
  devbox@127.0.0.1 \
  '! command -v docker && ! command -v gh && ! command -v codex && ! command -v node && ! command -v go'

echo "==> Recovery from a partial provisioning run"
run_playbook ansible/setup.yml 127.0.0.1 2404 --tags preflight,base
ssh -p 2404 -i "$key" -o UserKnownHostsFile="$known_hosts" -o StrictHostKeyChecking=yes \
  devbox@127.0.0.1 'command -v git >/dev/null && ! command -v docker >/dev/null'

for target in ubuntu-2204:2204 ubuntu-2404:2404; do
  host="${target%%:*}"
  port="${target##*:}"
  echo "==> Provisioning ${host}"
  first_log="/tmp/${host}-first.log"
  run_playbook ansible/setup.yml 127.0.0.1 "$port" | tee "$first_log"

  echo "==> Doctor ${host}"
  run_playbook ansible/doctor.yml 127.0.0.1 "$port"

  echo "==> Live Docker workload ${host}"
  for _ in $(seq 1 60); do
    if ssh -p "$port" -i "$key" -o UserKnownHostsFile="$known_hosts" -o StrictHostKeyChecking=yes \
      devbox@127.0.0.1 docker info >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  ssh -p "$port" -i "$key" -o UserKnownHostsFile="$known_hosts" -o StrictHostKeyChecking=yes \
    devbox@127.0.0.1 docker run --rm hello-world >/dev/null

  echo "==> Preserve user files and exclude credentials ${host}"
  ssh -p "$port" -i "$key" -o UserKnownHostsFile="$known_hosts" -o StrictHostKeyChecking=yes \
    devbox@127.0.0.1 \
    "grep -q 'pre-existing profile sentinel' ~/.profile && \
     grep -q 'pre-existing bashrc sentinel' ~/.bashrc && \
     grep -q 'pre-existing zshrc sentinel' ~/.zshrc && \
     grep -q 'DEVBOX-SETUP MANAGED BLOCK' ~/.profile && \
     test -d ~/workspace && test ! -e ~/.codex/auth.json"

  echo "==> Idempotency ${host}"
  second_log="/tmp/${host}-second.log"
  run_playbook ansible/setup.yml 127.0.0.1 "$port" | tee "$second_log"
  grep -Eq 'changed=0 .*failed=0' "$second_log"
done

echo "Full Ubuntu 22.04/24.04 E2E matrix passed."
