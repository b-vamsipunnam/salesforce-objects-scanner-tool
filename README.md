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

Install the project dependencies with:

```bash
python -m pip install -r requirements.txt
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

The scanner starts with four parallel workers. Increasing workers may reduce
runtime after validating Salesforce API capacity. Increase the value gradually
and watch for request-limit or transient service errors:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable PABOT_PROCESSES:8 src/robot/orchestrator/scan.robot
```

The scanner also uses `PABOT_SHARDS_PER_PROCESS` to create smaller queued batches
for better load balancing. The default value of `4` is suitable for most scans.

Successful per-object counts are hidden from the console by default. Progress,
skipped objects, operational failures, and the final summary remain visible. To
restore detailed successful-object output, enable verbose results:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable VERBOSE_OBJECT_RESULTS:true src/robot/orchestrator/scan.robot
```

If you only need business-data objects, skipping Tooling objects can save
considerable time:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable INCLUDE_TOOLING:false src/robot/orchestrator/scan.robot
```

## Performance and scale

Runtime depends on the number of discovered objects, available Salesforce API
capacity, Salesforce CLI startup overhead, object query complexity, network
latency, and the configured worker count. Start with the default four workers.
Increase `PABOT_PROCESSES` gradually only after validating Salesforce API
capacity; a larger value is not automatically faster.

### Benchmark template

Use this table to record comparable runs from your own environments. The blank
cells are intentional; this project does not publish universal runtime claims.

| Org Type  | Objects Discovered | Data Objects Counted | Tooling Objects Counted | Workers | Runtime | Notes                                                   |
|-----------|-------------------:|---------------------:|------------------------:|--------:|---------|---------------------------------------------------------|
| _Fill in_ |                  — |                    — |                       — |       — | —       | _API capacity, network conditions, or relevant context_ |

For a repeatable comparison of 1, 2, 4, 8, and 16 workers, see the
[benchmark guidance](docs/usage.md#increase-parallelism).

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

## Optional live Salesforce validation

Normal CI does not use Salesforce credentials. Maintainers can manually run the
`Live Salesforce Validation` workflow against a designated non-production org.
Before using it:

1. Create a GitHub Environment named `salesforce-live-validation`.
2. Add an environment secret named `SF_AUTH_URL` containing an SFDX auth URL for
   a sandbox, scratch org, or other approved non-production Salesforce org.
3. Add environment protection rules or required reviewers as appropriate.
4. Open **Actions → Live Salesforce Validation → Run workflow**.

The workflow fails before authentication when the secret is missing. Never place
the auth URL in repository files, workflow inputs, logs, issues, or pull requests.
It authenticates with the alias `live-validation`, runs a limited non-production
validation, and uploads the Robot Framework results as workflow artifacts.

## Documentation

- [Usage and configuration](docs/usage.md)
- [Architecture and execution flow](docs/architecture.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Contributing

Bug reports, practical examples, and focused pull requests are welcome. See
[Contributing](CONTRIBUTING.md) before submitting a change.

## Maintainer

Bhimeswara Vamsi Punnam - Lead Software Development Engineer in Test (SDET)

[LinkedIn](https://www.linkedin.com/in/bvamsipunnam)

## License

Licensed under the [MIT License](LICENSE).
