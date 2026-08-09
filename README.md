# Salesforce Objects Scanner

[![Robot Framework](https://img.shields.io/badge/Robot%20Framework-7.2.2-orange?style=flat&logo=robotframework&logoColor=white)](https://robotframework.org/)
[![CI](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/actions/workflows/robot-ci.yml/badge.svg)](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/actions)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat)](LICENSE)

A Salesforce org can contain hundreds or even thousands of objects. Checking each
one by hand is slow, and a failed query can easily interrupt the work.

Salesforce Objects Scanner handles that repetitive job. It discovers the objects
available to an authenticated user, counts them in parallel, records objects that
cannot be counted, and produces an Excel workbook that is ready to review.

It is useful for migration planning, storage reviews, cleanup projects, sandbox
planning, and finding objects with large data volumes.

## What you get

- Exact `SELECT COUNT()` results for standard and custom objects
- Optional Tooling API object counts
- Balanced parallel execution through Pabot, orchestrated in Robot Framework
- A timeout and isolated result for every object
- Clear reasons for unsupported or inaccessible objects
- JSON files for automation and a formatted Excel workbook for people

## How it works

[![Parallel Salesforce Object Count Scanner architecture](docs/architecture.svg)](docs/architecture.md)

## Requirements

- Python 3.9 or newer
- Salesforce CLI (`sf`)
- Access to an authenticated Salesforce org

Install the project dependencies with:

```bash
pip install -r requirements.txt
```

## Quick start

Authenticate and give the org a memorable alias:

```bash
sf org login web --alias MyOrg
```

Run the scanner:

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

The scanner uses four parallel workers by default. For a faster run, increase the
worker count carefully:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable PABOT_PROCESSES:8 src/robot/orchestrator/scan.robot
```

If you only need business-data objects, skipping Tooling objects can save
considerable time:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable INCLUDE_TOOLING:false src/robot/orchestrator/scan.robot
```

## Results

Each execution gets its own directory:

```text
output/Run_<date-time>_<id>/
|-- json/
|   |-- data_<date-time>.json
|   |-- tooling_<date-time>.json
|   |-- skipped_<date-time>.json
|   `-- durations_<date-time>.json
|-- pabot/
`-- SF_Objects_<date-time>.xlsx
```

Robot Framework's log and report are written to `results/`.
If an expired session, timeout, API-limit error, or malformed CLI response makes
the report incomplete, the scanner saves the available evidence and fails the
run instead of silently presenting a partial scan as successful.

## Documentation

- [Usage and configuration](docs/usage.md)
- [Architecture and execution flow](docs/architecture.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

## Contributing

Bug reports, practical examples, and focused pull requests are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change.

## Maintainer

Bhimeswara Vamsi Punnam - Lead Software Development Engineer in Test (SDET)

[LinkedIn](https://www.linkedin.com/in/bvamsipunnam)

## License

Licensed under the [MIT License](LICENSE).
