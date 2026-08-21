#!/usr/bin/env python3
"""Validate a devbox profile before any remote connection is attempted."""

from __future__ import annotations

import json
import pathlib
import sys

import yaml
from jsonschema import Draft202012Validator


def fail(message: str) -> None:
    print(f"config error: {message}", file=sys.stderr)
    raise SystemExit(2)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate_config.py PATH")

    config_path = pathlib.Path(sys.argv[1])
    schema_path = pathlib.Path(__file__).with_name("config.schema.json")

    try:
        config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"file not found: {config_path}")
    except yaml.YAMLError as exc:
        fail(f"invalid YAML: {exc}")

    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    errors = sorted(
        Draft202012Validator(schema).iter_errors(config),
        key=lambda error: list(error.absolute_path),
    )
    if errors:
        for error in errors:
            location = ".".join(str(part) for part in error.absolute_path) or "<root>"
            print(f"config error: {location}: {error.message}", file=sys.stderr)
        raise SystemExit(2)

    if config["features"]["codex"]["enabled"] and not config["runtimes"]["node"]["enabled"]:
        fail("features.codex.enabled requires runtimes.node.enabled")

    print(f"configuration valid: {config_path}")


if __name__ == "__main__":
    main()
