# Salesforce Objects Scanner

[![Robot Framework](https://img.shields.io/badge/Robot%20Framework-7.2.2-orange?style=flat&logo=robotframework&logoColor=white)](https://robotframework.org/)
[![CI](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/actions/workflows/robot-ci.yml/badge.svg)](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/actions)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat)](LICENSE)

Salesforce Objects Scanner discovers the objects available to an authenticated
user, counts their records in parallel, records objects that cannot be counted,
and produces an Excel workbook ready for review.

Use it for migration planning, storage reviews, cleanup projects, sandbox
planning, and identifying objects with large data volumes.

## What you get

- Exact `SELECT COUNT()` results for supported standard and custom objects
- Optional Tooling API object counts
- Parallel execution with per-object timeouts and isolated results
- Clear reasons and sanitized Salesforce details for objects that cannot be counted
- JSON files for automation and a formatted Excel workbook for review

## Requirements

- Python 3.10 or newer
- Salesforce CLI (`sf`)
- Access to an authenticated Salesforce org

Create and activate a virtual environment:

```bash
python -m venv .venv
```

On Windows:

```powershell
.venv\Scripts\Activate.ps1
```

On macOS or Linux:

```bash
source .venv/bin/activate
```

Install the dependencies:

```bash
python -m pip install -r requirements.txt
```

## Quick start

Authenticate and assign an org alias:

```bash
sf org login web --alias MyOrg
```

Run the scanner:

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

## Common options

For a faster business-data-only scan, exclude Tooling API objects:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable INCLUDE_TOOLING:false src/robot/orchestrator/scan.robot
```

For concurrency, verbosity, benchmarking, and all configuration options, see
[Usage and configuration](docs/usage.md).

## Results and required review

Each scan writes its Excel workbook and JSON evidence beneath:

```text
output/Run_<date-time>_<id>/
```

Robot Framework's log and report are written to `results/`.

The person running the scanner **must open the generated Excel workbook and
review every row in the `Skipped Objects` worksheet**, even when the run passes.
A passing run means no unexpected operational failure was detected; it does not
mean every discovered Salesforce object produced a count. Confirm that every
omission is acceptable before treating the scan as complete.

## Documentation

- [Usage and configuration](docs/usage.md)
- [Architecture and execution flow](docs/architecture.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [MIT License](LICENSE)

## Contributing

Bug reports, practical examples, and focused pull requests are welcome. Read
[CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change.

## Security

Report vulnerabilities using the process in [SECURITY.md](SECURITY.md).

## License

Licensed under the [MIT License](LICENSE).
