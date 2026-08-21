FROM python:3.13.7-slim-bookworm

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        openssh-client \
        shellcheck \
    && rm -rf /var/lib/apt/lists/*

COPY requirements/controller.txt /tmp/controller.txt
RUN pip install --no-cache-dir --requirement /tmp/controller.txt

WORKDIR /workspace
