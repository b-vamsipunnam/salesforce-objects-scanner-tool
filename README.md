# Salesforce Objects Scanner

[![Robot Framework](https://img.shields.io/badge/Robot%20Framework-7.4.2-orange?style=flat&logo=robotframework&logoColor=white)](https://robotframework.org/)
[![Python](https://img.shields.io/badge/Python-3.10+-blue?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![Salesforce CLI](https://img.shields.io/badge/Salesforce-CLI-00A1E0?style=flat&logo=salesforce&logoColor=white)](https://developer.salesforce.com/tools/salesforcecli)
[![CI](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/actions/workflows/robot-ci.yml/badge.svg)](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/actions)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat)](LICENSE)

Salesforce Objects Scanner builds an inventory of the objects available to a
Salesforce user and runs `SELECT COUNT()` against them in parallel. It saves the
counts, query times, and skipped objects to JSON files and an Excel workbook.

The scanner is useful when sizing a migration, reviewing storage, or finding
large objects before a cleanup. It discovers objects from the org at runtime, so
there is no object list to maintain by hand.

## What the scan includes

- standard and custom objects returned by Salesforce CLI;
- queryable Tooling API objects, unless Tooling discovery is disabled;
- a separate timeout for each object;
- retries for a small set of transient Salesforce errors;
- the Salesforce reason for any object that could not be counted; and
- an isolated output directory for each run.

Errors are redacted before they are written to disk, but scan output may still
contain sensitive org information. Store and share it accordingly.

## Quick start

You need Python 3.10 or later, Salesforce CLI, and access to a Salesforce org.

```bash
git clone https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool.git
cd salesforce-objects-scanner-tool
python -m venv venv
python -m pip install -r requirements.txt
sf org login web --alias MyOrg
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

See [Installation](docs/installation.md) for virtual-environment activation and
[Authentication](docs/authentication.md) for Salesforce CLI login details.

## Results

Each scan creates a directory under `output/`:

```text
output/Run_<date-time>_<id>/
|-- json/
|-- pabot/
`-- SF_Objects_<date-time>.xlsx
```

Robot Framework writes its log and report to `results/` when the quick-start
command is used.

Always open the workbook and check every row in `Skipped Objects`. A passing
Robot run means there were no unexpected operational errors; it does not mean
that Salesforce allowed every discovered object to be counted. A missing count
must not be treated as zero.

## Documentation

| Guide                                      | What it covers                                |
|--------------------------------------------|-----------------------------------------------|
| [Installation](docs/installation.md)       | Prerequisites and local setup                 |
| [Authentication](docs/authentication.md)   | Salesforce CLI login and permissions          |
| [Configuration](docs/configuration.md)     | Robot variables, defaults, and timeouts       |
| [Usage](docs/usage.md)                     | Running a scan and reading its output         |
| [Architecture](docs/architecture.md)       | Execution flow and component responsibilities |
| [Troubleshooting](docs/troubleshooting.md) | Common failures and practical fixes           |
| [Limitations](docs/limitations.md)         | What the counts do and do not represent       |

Contributor setup and project checks are in [CONTRIBUTING.md](CONTRIBUTING.md).
Please also read the [Code of Conduct](CODE_OF_CONDUCT.md) and
[Security Policy](SECURITY.md) before contributing.

## Repository layout

```text
ci/                      CI-safe Robot suites and fake Salesforce CLI
docs/                    User and architecture guides
src/robot/libraries/     Python helpers and Excel output
src/robot/orchestrator/  Scanner entry point
src/robot/resources/     Robot Framework resources
tests/                   Python unit tests
output/                  Generated scan output
```

## License

Licensed under the [MIT License](LICENSE).
