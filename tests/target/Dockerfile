ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        openssh-server \
        procps \
        python3 \
        sudo \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && useradd --create-home --shell /bin/bash devbox \
    && useradd --create-home --shell /bin/bash nosudo \
    && printf 'devbox ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/devbox \
    && chmod 0440 /etc/sudoers.d/devbox \
    && printf 'PasswordAuthentication no\nPermitRootLogin no\n' >/etc/ssh/sshd_config.d/devbox.conf \
    && printf '\n# pre-existing profile sentinel\n' >>/home/devbox/.profile \
    && printf '# pre-existing bashrc sentinel\n' >>/home/devbox/.bashrc \
    && printf '# pre-existing zshrc sentinel\n' >/home/devbox/.zshrc \
    && chown devbox:devbox /home/devbox/.profile /home/devbox/.bashrc /home/devbox/.zshrc

COPY tests/target/entrypoint.sh /usr/local/bin/devbox-test-entrypoint
RUN chmod 0755 /usr/local/bin/devbox-test-entrypoint

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/devbox-test-entrypoint"]
