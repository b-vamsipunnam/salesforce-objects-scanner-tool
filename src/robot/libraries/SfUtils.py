"""Small cross-platform helpers exposed as Robot Framework keywords."""

from __future__ import annotations

import json
import shutil
import sys
from typing import Any


def resolve_executable(name: str) -> str:
    """Return the executable path or raise a clear error."""
    path = shutil.which(name)
    if path is None:
        raise AssertionError(f"{name} was not found in PATH.")
    return path


def parse_sf_json(raw: str) -> Any:
    """Decode Salesforce's JSON payload from potentially noisy CLI output."""
    if not raw or not raw.strip():
        raise ValueError("No output returned from sf.")
    decoder = json.JSONDecoder()
    text = raw.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    candidates = []
    for index, character in enumerate(text):
        if character not in "[{":
            continue
        try:
            value, _ = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            continue
        candidates.append(value)
    if candidates:
        return max(enumerate(candidates), key=_candidate_priority)[1]
    raise ValueError("No valid JSON value found in sf output.")


def _candidate_priority(indexed_value: tuple[int, Any]) -> tuple[int, int]:
    """Prefer complete Salesforce payloads and, for ties, later values."""
    index, value = indexed_value
    if isinstance(value, dict):
        if "status" in value and "result" in value:
            score = 100
        elif "name" in value and "message" in value:
            score = 80
        elif "status" in value:
            score = 70
        elif "result" in value:
            score = 60
        elif "name" in value:
            score = 30
        else:
            score = 10
    elif isinstance(value, list):
        score = 50
    else:
        score = 0
    return score, index


def current_python_executable() -> str:
    """Return the interpreter running Robot Framework."""
    return sys.executable
