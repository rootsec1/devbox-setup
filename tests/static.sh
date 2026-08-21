#!/usr/bin/env bash
set -Eeuo pipefail
cd /workspace

echo "==> ShellCheck"
find bin scripts tests -type f -name '*.sh' -print0 \
  | xargs -0 shellcheck
shellcheck bin/devbox scripts/run-controller.sh

echo "==> YAML lint"
yamllint -d '{extends: default, rules: {line-length: {max: 140}, truthy: disable}}' \
  devbox.yml compose.yaml ansible .github/workflows

echo "==> Ansible lint"
ansible-lint ansible/setup.yml ansible/doctor.yml

echo "==> Syntax checks"
ANSIBLE_CONFIG=/workspace/ansible/ansible.cfg \
  ansible-playbook --syntax-check ansible/setup.yml --inventory localhost,
ANSIBLE_CONFIG=/workspace/ansible/ansible.cfg \
  ansible-playbook --syntax-check ansible/doctor.yml --inventory localhost,

echo "==> Configuration validation"
python3 tools/validate_config.py devbox.yml

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

sed '/extra_packages:/a unknown_key: true' devbox.yml >"$tmp_dir/unknown.yml"
if python3 tools/validate_config.py "$tmp_dir/unknown.yml"; then
  echo "unknown configuration key was accepted" >&2
  exit 1
fi

sed '0,/enabled: true/s//enabled: false/' devbox.yml >"$tmp_dir/node-disabled.yml"
if python3 tools/validate_config.py "$tmp_dir/node-disabled.yml"; then
  echo "Codex without Node was accepted" >&2
  exit 1
fi

echo "==> CLI argument validation"
bin/devbox --version | grep -Eq '^devbox [0-9]+\.[0-9]+\.[0-9]+$'
bin/devbox --help | grep -q 'devbox setup'
if bin/devbox setup --host 'bad host' --user devbox; then
  echo "invalid host was accepted" >&2
  exit 1
fi
if bin/devbox setup --host example.test --user 'Bad User'; then
  echo "invalid user was accepted" >&2
  exit 1
fi

echo "All static checks passed."
