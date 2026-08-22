"""Deterministic Salesforce CLI stand-in used only by Robot integration tests."""

import json
import re
import sys
import time


COUNTS = {"Account": 42, "Contact": 7, "ApexClass": 3}


def main() -> int:
    arguments = sys.argv[1:]
    if arguments[:2] == ["sobject", "list"]:
        names = [f"LargeDiscoveryObject{index}__c" for index in range(10_000)]
        print(json.dumps({"status": 0, "result": names}))
        return 0
    if arguments[:2] != ["data", "query"] or "--query" not in arguments:
        print(json.dumps({"name": "UNSUPPORTED_FAKE_COMMAND"}))
        return 1
    query = arguments[arguments.index("--query") + 1]
    match = re.fullmatch(r"SELECT COUNT\(\) FROM ([A-Za-z][A-Za-z0-9_]*)", query)
    if match and match.group(1) == "SleepObject":
        time.sleep(10)
        return 0
    if match and match.group(1) == "SlowObject":
        time.sleep(1.25)
        print(
            json.dumps(
                {
                    "status": 0,
                    "result": {"records": [], "totalSize": 11, "done": True},
                }
            )
        )
        return 0
    if match and match.group(1) == "ExternalFailure":
        print(
            json.dumps(
                {
                    "name": "EXTERNAL_OBJECT_EXCEPTION",
                    "message": "Provider temporarily unavailable",
                }
            )
        )
        return 1
    if match and match.group(1) == "DeterministicExternalFailure":
        print(
            json.dumps(
                {
                    "name": "EXTERNAL_OBJECT_EXCEPTION",
                    "message": "Cannot access: TestFeature in this organization",
                }
            )
        )
        return 1
    if not match or match.group(1) not in COUNTS:
        print(json.dumps({"name": "INVALID_TYPE", "message": query}))
        return 1
    print(
        json.dumps(
            {
                "status": 0,
                "result": {
                    "records": [],
                    "totalSize": COUNTS[match.group(1)],
                    "done": True,
                },
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
