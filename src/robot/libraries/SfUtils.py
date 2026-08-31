"""Small cross-platform helpers exposed as Robot Framework keywords."""

from __future__ import annotations

import json
import os
import re
import signal
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any


MAX_RETAINED_ERROR_LENGTH = 4000

# Verified against persisted Salesforce responses from the 2026-08-10 DevHub
# scan. Rules bind object identity, API context, error code, and message pattern.
VERIFIED_RESTRICTIVE_FILTER_RULES = (
    (
        "ContentDocumentLink",
        False,
        "MALFORMED_QUERY",
        r"^Implementation restriction: ContentDocumentLink requires a filter by ",
    ),
    (
        "ContentFolderItem",
        False,
        "MALFORMED_QUERY",
        r"^Implementation restriction: ContentFolderItem requires a filter by ",
    ),
    (
        "ContentFolderMember",
        False,
        "MALFORMED_QUERY",
        r"^Implementation restriction: ContentFolderMember requires a filter by ",
    ),
    (
        "ContentVersionRenditionContent",
        False,
        "MALFORMED_QUERY",
        r"^ContentVersionId must be specified in your query\.$",
    ),
    (
        "IdeaComment",
        False,
        "MALFORMED_QUERY",
        r"^Implementation restriction\. When querying the Idea Comment object, you must filter ",
    ),
    (
        "Vote",
        False,
        "MALFORMED_QUERY",
        r"^Implementation restriction: When querying the Vote object, you must filter ",
    ),
    (
        "SubscriberPackage",
        True,
        "MALFORMED_QUERY",
        r"^Implementation restriction: You can only perform queries of the form Id=",
    ),
    (
        "DataStatistics",
        False,
        "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
        r"^Where clauses should contain StatType$",
    ),
    (
        "DatacloudDandBCompany",
        False,
        "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
        r"^Datacloud D&B company is not filterable without a criteria\.$",
    ),
    (
        "FlexQueueItem",
        False,
        "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
        r"^The WHERE clause must contain a JobType field expression\.$",
    ),
)

VERIFIED_QUERY_UNSUPPORTED_RULES = (
    (
        "EventBusSubscriber",
        False,
        "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
        r"^COUNT\(\) query could not be processed$",
    ),
    (
        "PendingOrderSummary",
        False,
        "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
        r"^COUNT\(\) query could not be processed$",
    ),
    (
        "DatacloudAddress",
        False,
        "EXTERNAL_OBJECT_EXCEPTION",
        r"^SObject - DATACLOUD_ADDRESS : Transient queries are not implemented$",
    ),
)

VERIFIED_NON_RETRYABLE_EXTERNAL_RULES = (
    (
        "PlatformEventUsageMetric",
        False,
        "EXTERNAL_OBJECT_EXCEPTION",
        r'^The "Id" field is of type number, but the value from the external system is ',
    ),
    (
        "UserAppMenuItem",
        False,
        "EXTERNAL_OBJECT_EXCEPTION",
        r'^The "Id" field is of type number, but the value from the external system is ',
    ),
)

DETERMINISTIC_EXTERNAL_MESSAGE_PATTERNS = (
    r"^Cannot access: .+ in this organization$",
    r"^Unable to invoke method: ",
)

TRANSIENT_ERROR_MESSAGE_PATTERN = re.compile(
    r"(?:temporar(?:y|ily)|try again|request limit|rate limit|too many requests|"
    r"service unavailable|server unavailable|internal server error|connection (?:reset|refused)|"
    r"socket hang up|econnreset|etimedout|unexpected error occurred)",
    re.IGNORECASE,
)


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
            value, end_offset = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            continue
        candidates.append((value, index, index + end_offset))
    if candidates:
        return max(candidates, key=_candidate_priority)[0]
    raise ValueError("No valid JSON value found in sf output.")


def _candidate_priority(candidate: tuple[Any, int, int]) -> tuple[int, int, int]:
    """Prefer recognized payloads, then the largest complete JSON document."""
    value, start, end = candidate
    if isinstance(value, dict):
        if "status" in value and "result" in value:
            score = 100
        elif "sobjects" in value and isinstance(value["sobjects"], list):
            score = 95
        elif "name" in value and "message" in value:
            score = 90
        elif "status" in value:
            score = 80
        elif "result" in value:
            score = 75
        elif "name" in value:
            score = 70
        else:
            score = 60
    elif isinstance(value, list):
        score = 50
    else:
        score = 0
    return score, end - start, -start


def run_sf_command_safely(
    executable: str,
    command_parts: list[Any],
    output_directory: str,
    timeout_seconds: float,
    expect_json: bool = True,
) -> dict[str, Any]:
    """Run sf with file-backed streams and return no unsanitized process output."""
    directory = Path(output_directory)
    directory.mkdir(parents=True, exist_ok=True)
    stdout_fd, stdout_name = tempfile.mkstemp(prefix=".sf-", suffix=".stdout", dir=directory)
    stderr_fd, stderr_name = tempfile.mkstemp(prefix=".sf-", suffix=".stderr", dir=directory)
    stdout_path = Path(stdout_name)
    stderr_path = Path(stderr_name)
    timed_out = False
    return_code: int | None = None
    try:
        with os.fdopen(stdout_fd, "wb") as stdout_file, os.fdopen(
            stderr_fd, "wb"
        ) as stderr_file:
            try:
                process = subprocess.Popen(
                    [str(executable), *(str(part) for part in command_parts)],
                    stdout=stdout_file,
                    stderr=stderr_file,
                    creationflags=(
                        subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
                    ),
                    start_new_session=os.name != "nt",
                )
                try:
                    return_code = process.wait(timeout=float(timeout_seconds))
                except subprocess.TimeoutExpired:
                    timed_out = True
                    _kill_process_tree(process)
                    process.wait()
            except OSError as exc:
                return {
                    "ok": False,
                    "rc": None,
                    "timed_out": False,
                    "data": None,
                    "details": {
                        "name": "CLI_EXECUTION_FAILED",
                        "message": sanitize_sf_text(str(exc)),
                    },
                }

        stdout = stdout_path.read_text(encoding="utf-8", errors="replace")
        stderr = stderr_path.read_text(encoding="utf-8", errors="replace")
        if timed_out:
            return {
                "ok": False,
                "rc": return_code,
                "timed_out": True,
                "data": None,
                "details": {
                    "name": "TIMEOUT",
                    "message": f"Salesforce CLI exceeded {timeout_seconds} seconds.",
                },
            }
        if return_code != 0:
            return {
                "ok": False,
                "rc": return_code,
                "timed_out": False,
                "data": None,
                "details": get_sf_error_details(f"{stdout}\n{stderr}"),
            }
        if not expect_json:
            return {
                "ok": True,
                "rc": return_code,
                "timed_out": False,
                "data": None,
                "details": {
                    "name": "OK",
                    "message": sanitize_sf_text(f"{stdout}\n{stderr}".strip()),
                },
            }
        try:
            data = sanitize_sf_payload(parse_sf_json(stdout))
        except ValueError:
            return {
                "ok": False,
                "rc": return_code,
                "timed_out": False,
                "data": None,
                "details": {
                    "name": "INVALID_JSON_OUTPUT",
                    "message": get_sf_error_details(f"{stdout}\n{stderr}")["message"],
                },
            }
        return {
            "ok": True,
            "rc": return_code,
            "timed_out": False,
            "data": data,
            "details": {"name": "OK", "message": ""},
        }
    finally:
        _unlink_capture_file(stdout_path)
        _unlink_capture_file(stderr_path)


def _kill_process_tree(process: subprocess.Popen[Any]) -> None:
    """Terminate the CLI wrapper and descendants that inherited capture files."""
    if os.name == "nt":
        try:
            os.kill(process.pid, signal.CTRL_BREAK_EVENT)
            process.wait(timeout=2)
            return
        except (OSError, subprocess.TimeoutExpired):
            pass
        subprocess.run(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    if process.poll() is None:
        process.kill()


def _unlink_capture_file(path: Path) -> None:
    """Remove a capture file after inherited process handles have closed."""
    for attempt in range(5):
        try:
            path.unlink(missing_ok=True)
            return
        except PermissionError:
            if attempt == 4:
                raise
            time.sleep(0.05)


def get_latest_sf_api_version(versions: Any) -> str:
    """Return the highest API version from the safe /services/data/ response."""
    if not isinstance(versions, list):
        raise AssertionError("Salesforce /services/data/ response was not a list.")
    values = [
        str(item.get("version"))
        for item in versions
        if isinstance(item, dict) and item.get("version")
    ]
    if not values:
        raise AssertionError("Salesforce /services/data/ response contained no API versions.")
    return max(values, key=lambda value: tuple(int(part) for part in value.split(".")))


def sanitize_sf_payload(value: Any, key: str = "") -> Any:
    """Recursively redact credentials before parsed CLI data reaches Robot."""
    normalized_key = re.sub(r"[^a-z]", "", key.lower())
    if normalized_key in {
        "accesstoken",
        "authtoken",
        "refreshtoken",
        "sessionid",
        "sfdxauthurl",
    }:
        return "[REDACTED_CREDENTIAL]"
    if isinstance(value, dict):
        return {
            item_key: sanitize_sf_payload(item_value, str(item_key))
            for item_key, item_value in value.items()
        }
    if isinstance(value, list):
        return [sanitize_sf_payload(item) for item in value]
    if isinstance(value, str):
        return sanitize_sf_text(value)
    return value


def current_python_executable() -> str:
    """Return the interpreter running Robot Framework."""
    return sys.executable


def get_sf_error_details(raw: str) -> dict[str, Any]:
    """Return a sanitized, report-safe subset of a Salesforce CLI error."""
    try:
        payload = parse_sf_json(raw)
    except ValueError:
        return {
            "name": "UNPARSEABLE_CLI_ERROR",
            "message": _redact_sensitive_text(raw),
        }
    if not isinstance(payload, dict):
        return {
            "name": "INVALID_JSON_STRUCTURE",
            "message": "Salesforce CLI returned a JSON value that was not an object.",
        }
    details = {}
    for key in ("name", "message", "status", "exitCode", "code", "commandName"):
        if key in payload and payload[key] is not None:
            value = payload[key]
            details[key] = sanitize_sf_text(value) if isinstance(value, str) else value
    if "name" not in details:
        details["name"] = "UNKNOWN_SALESFORCE_ERROR"
    if "message" not in details:
        details["message"] = "Salesforce CLI returned no error message."
    return details


def classify_sf_error(
    raw: str,
    object_name: str = "",
    tooling: bool = False,
    allow_disabled_datacloud: bool = False,
    known_unknown_limitation: bool = False,
) -> str:
    """Classify only verified object/code/message combinations as expected."""
    details = get_sf_error_details(raw)
    name = str(details.get("name", "OTHER_ERROR"))
    message = str(details.get("message", ""))
    object_name = str(object_name)

    if "Count operation not supported" in message:
        return "COUNT_NOT_SUPPORTED"
    if (
        name == "INVALID_TYPE_FOR_OPERATION"
        and object_name
        and re.search(
            rf"\bentity type {re.escape(object_name)} does not support query\b",
            message,
            re.IGNORECASE,
        )
    ):
        return "QUERY_NOT_SUPPORTED"
    if (
        name == "BIG_OBJECT_UNSUPPORTED_OPERATION"
        and message == "Aggregate functions not supported"
    ):
        return "BIG_OBJECT_COUNT_UNSUPPORTED"
    if (
        name == "MALFORMED_QUERY"
        and object_name
        and message.startswith(
            f"{object_name}: a filter on a reified column is required"
        )
    ):
        return "RESTRICTIVE_FILTER_REQUIRED"
    if (
        name == "MALFORMED_QUERY"
        and object_name == "DataStatistics"
        and "Where clauses should contain StatType" in message
    ):
        return "RESTRICTIVE_FILTER_REQUIRED"
    if (
        name == "INVALID_FIELD"
        and object_name == "UserRecordAccess"
        and "RecordId field must be selected" in message
    ):
        return "RESTRICTIVE_FILTER_REQUIRED"
    if name == "ID_REQUIRED" and "Implementation restriction" in message:
        return "RESTRICTIVE_FILTER_REQUIRED"
    if _matches_verified_rule(
        object_name,
        tooling,
        name,
        message,
        VERIFIED_RESTRICTIVE_FILTER_RULES,
    ):
        return "RESTRICTIVE_FILTER_REQUIRED"
    if _matches_verified_rule(
        object_name,
        tooling,
        name,
        message,
        VERIFIED_QUERY_UNSUPPORTED_RULES,
    ):
        return "QUERY_NOT_SUPPORTED"
    if name in {
        "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
        "DEPENDENCY_API_UNSUPPORTED_EXCEPTION",
    } and re.search(r"\b(not supported|unsupported)\b", message, re.IGNORECASE):
        return "QUERY_NOT_SUPPORTED"
    if (
        name == "DATACLOUD_API_DISABLED_EXCEPTION"
        and _to_bool(allow_disabled_datacloud)
        and "doesn't have permission to access the Data.com API" in message
    ):
        return "DATACLOUD_INTENTIONALLY_DISABLED"
    # These named objects repeatedly return the same platform-side internal
    # error for COUNT(). Keep this narrow and preserve the ErrorId in details.
    if (
        name == "UNKNOWN_EXCEPTION"
        and _to_bool(known_unknown_limitation)
        and re.search(r"unexpected error occurred.*ErrorId", message, re.IGNORECASE)
    ):
        return "COUNT_NOT_SUPPORTED"
    return name if name else "OTHER_ERROR"


def is_sf_failure_retryable(
    reason: str,
    details: dict[str, Any],
    object_name: str = "",
    tooling: bool = False,
) -> bool:
    """Return whether a configured failure has evidence of being transient."""
    reason = str(reason)
    message = str(details.get("message", ""))
    object_name = str(object_name)

    if reason == "REQUEST_LIMIT_EXCEEDED":
        return True
    if reason not in {"EXTERNAL_OBJECT_EXCEPTION", "UNKNOWN_EXCEPTION"}:
        return True
    if is_verified_deterministic_sf_failure(
        reason,
        details,
        object_name,
        tooling,
    ):
        return False
    return TRANSIENT_ERROR_MESSAGE_PATTERN.search(message) is not None


def is_verified_deterministic_sf_failure(
    reason: str,
    details: dict[str, Any],
    object_name: str = "",
    tooling: bool = False,
) -> bool:
    """Match only verified deterministic external-failure evidence."""
    reason = str(reason)
    message = str(details.get("message", ""))
    if reason != "EXTERNAL_OBJECT_EXCEPTION":
        return False
    if _matches_verified_rule(
        object_name,
        tooling,
        reason,
        message,
        VERIFIED_NON_RETRYABLE_EXTERNAL_RULES,
    ):
        return True
    return any(
        re.search(pattern, message)
        for pattern in DETERMINISTIC_EXTERNAL_MESSAGE_PATTERNS
    )


def _to_bool(value: Any) -> bool:
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return bool(value)


def _matches_verified_rule(
    object_name: str,
    tooling: Any,
    error_name: str,
    message: str,
    rules: tuple[tuple[str, bool, str, str], ...],
) -> bool:
    tooling = _to_bool(tooling)
    for expected_object, expected_tooling, expected_error, message_pattern in rules:
        if (
            object_name == expected_object
            and tooling == expected_tooling
            and error_name == expected_error
            and re.search(message_pattern, message)
        ):
            return True
    return False


def _redact_sensitive_text(raw: str) -> str:
    return sanitize_sf_text(raw)


def sanitize_sf_text(value: Any) -> str:
    """Redact common Salesforce credentials from one externally sourced string."""
    text = str(value or "").strip()
    substitutions = (
        (r"(?i)force://[^\s\"'<>]+", "[REDACTED_AUTH_URL]"),
        (r"(?i)force%3a%2f%2f[^\s\"'<>]+", "[REDACTED_AUTH_URL]"),
        (
            r"(?i)authorization\s*:\s*bearer\s+[^\s,;\"'<>]+",
            "Authorization: Bearer [REDACTED_BEARER_TOKEN]",
        ),
        (
            r"(?i)authorization%3a(?:%20|\+)*bearer(?:%20|\+)+[^&\s\"'<>]+",
            "Authorization%3A%20Bearer%20[REDACTED_BEARER_TOKEN]",
        ),
        (r"(?i)bearer\s+[^\s,;\"'<>]+", "Bearer [REDACTED_BEARER_TOKEN]"),
        (
            r"(?i)(session[_ -]?id|sid)\s*[:=]\s*[^\s,;&\"'<>]+",
            r"\1=[REDACTED_SESSION_ID]",
        ),
        (
            r"(?i)(session[_ -]?id|sid)(?:%3d|%3a)(?:%20|\+)*[^&\s\"'<>]+",
            r"\1%3D[REDACTED_SESSION_ID]",
        ),
        (
            r"(?i)(access[_ -]?token)\s*[:=]\s*[^\s,;&\"'<>]+",
            r"\1=[REDACTED_ACCESS_TOKEN]",
        ),
        (
            r"(?i)(access[_ -]?token)(?:%3d|%3a)(?:%20|\+)*[^&\s\"'<>]+",
            r"\1%3D[REDACTED_ACCESS_TOKEN]",
        ),
        (
            r"(?i)(refresh[_ -]?token)\s*[:=]\s*[^\s,;&\"'<>]+",
            r"\1=[REDACTED_REFRESH_TOKEN]",
        ),
        (
            r"(?i)(client[_ -]?secret)\s*[:=]\s*[^\s,;&\"'<>]+",
            r"\1=[REDACTED_CLIENT_SECRET]",
        ),
        (
            r"(?i)https?://[^\s/@:\"'<>]+:[^\s/@\"'<>]+@[^\s\"'<>]+",
            "[REDACTED_CREDENTIAL_URL]",
        ),
        (
            r"\b00D[A-Za-z0-9]{12,15}![A-Za-z0-9._-]+\b",
            "[REDACTED_SESSION_ID]",
        ),
    )
    for pattern, replacement in substitutions:
        text = re.sub(pattern, replacement, text)
    if len(text) > MAX_RETAINED_ERROR_LENGTH:
        suffix = "...[TRUNCATED]"
        text = text[: MAX_RETAINED_ERROR_LENGTH - len(suffix)] + suffix
    return text
