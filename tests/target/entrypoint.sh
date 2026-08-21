#!/usr/bin/env bash
set -Eeuo pipefail

install_key() {
  local account="$1"
  local home_dir="/home/${account}"
  install -d -m 0700 -o "$account" -g "$account" "${home_dir}/.ssh"
  install -m 0600 -o "$account" -g "$account" \
    /run/test-keys/id_ed25519.pub "${home_dir}/.ssh/authorized_keys"
}

for _ in $(seq 1 30); do
  [[ -s /run/test-keys/id_ed25519.pub ]] && break
  sleep 1
done
[[ -s /run/test-keys/id_ed25519.pub ]] || { echo "test SSH key not available" >&2; exit 1; }

install_key devbox
install_key nosudo
touch /run/devbox-test-target

printf 'Port %s\n' "${DEVBOX_TEST_SSH_PORT:-22}" >/etc/ssh/sshd_config.d/test-port.conf

# Docker is installed by the role. Start its daemon as soon as the package
# appears so the same production tasks can be tested without preinstalling it.
(
  while ! command -v dockerd >/dev/null 2>&1; do sleep 2; done
  dockerd \
    --host=unix:///var/run/docker.sock \
    --storage-driver=vfs \
    --iptables=false \
    --bridge=none \
    >/var/log/devbox-test-dockerd.log 2>&1
) &

exec /usr/sbin/sshd -D -e
