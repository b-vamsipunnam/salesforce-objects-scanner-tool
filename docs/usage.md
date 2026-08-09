# Usage Guide

This guide covers installation, configuration, outputs, performance, and common
problems. For the components and execution model, see
[Architecture](architecture.md).

## Install the scanner

You need Python 3.9 or newer, Salesforce CLI, and access to a Salesforce org.
If Salesforce CLI was installed through npm, Node.js is also required.

Clone the repository and create a virtual environment:

```bash
git clone https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool.git
cd salesforce-objects-scanner-tool
python -m venv venv
```

Activate it on Windows:

```powershell
venv\Scripts\Activate.ps1
```

Or on macOS and Linux:

```bash
source venv/bin/activate
```

Install the pinned dependencies:

```bash
pip install -r requirements.txt
```

Confirm that Salesforce CLI is available:

```bash
sf --version
```

## Authenticate an org

The scanner uses the existing Salesforce CLI session. It does not store a
username, password, access token, or connected-app secret.

```bash
sf org login web --alias MyOrg
sf org display --target-org MyOrg
```

The second command is a useful check before starting a long scan.

## Run a scan

From the repository root, run:

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

`scan.robot` performs discovery once and starts Pabot internally. Pabot runs
balanced suites of standard and Tooling objects, while the parent run combines
their isolated results into the final reports.

### Configuration

| Variable | Required | Default | Purpose |
|---|---:|---:|---|
| `ORG_ALIAS` | Yes | Empty | Authenticated Salesforce CLI alias |
| `PABOT_PROCESSES` | No | `4` | Number of concurrent object-query workers |
| `PABOT_SHARDS_PER_PROCESS` | No | `4` | Queued suites per worker for load balancing |
| `INCLUDE_TOOLING` | No | `true` | Discover and include queryable Tooling API objects |
| `MAX_QUERY_TIMEOUT_SECONDS` | No | `120` | Timeout for a normal object query |
| `CONNECTEDAPP_TIMEOUT` | No | `180` | Extended timeout for known slow objects |
| `SCAN_OUTPUT_ROOT` | No | `<repository>/output` | Root directory for completed scans |
| `FAIL_ON_OPERATIONAL_ERRORS` | No | `true` | Fail after saving reports when operational errors occur |

Robot variables are passed with `--variable NAME:value`. Multiple variables can
be supplied in the same command:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable PABOT_PROCESSES:8 --variable INCLUDE_TOOLING:false src/robot/orchestrator/scan.robot
```

## Choose the right scan

### Standard and custom objects only

Most admins who are reviewing storage or preparing a data migration do not need
Tooling API counts. Disable them to reduce the work list:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable INCLUDE_TOOLING:false src/robot/orchestrator/scan.robot
```

### Include Tooling objects

Tooling discovery is enabled by default. This adds objects used for development
and metadata-related analysis, so the run takes longer and the report is larger.
The scanner never substitutes a hard-coded Tooling object list. If live discovery
fails, it prints the Salesforce response, lets data-object queries finish, records
`TOOLING::DISCOVERY=TOOLING_DISCOVERY_FAILED`, and fails the quality gate.

### Increase parallelism

Four workers is a conservative default. Eight is often a reasonable starting
point for a faster run:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable PABOT_PROCESSES:8 src/robot/orchestrator/scan.robot
```

More workers are not always faster. Salesforce API capacity, network latency,
local CPU, and repeated CLI startup all affect throughput. Increase concurrency
gradually, run during a quieter period, and reduce it if the scan reports request
limit or transient service errors.

The worker count is fixed when Pabot starts. It cannot be changed during an active
run.

## Follow progress

Pabot's console output is saved inside the isolated run directory. During
execution, each finished object creates one JSON artifact beneath:

```text
output/Run_<date-time>_<id>/pabot/artifacts/
```

The number of artifact files is the number of completed object queries. Generated
balanced suites are visible under `pabot/workers/`.

Do not edit or remove the run directory while a scan is active. The parent process
uses those artifacts to verify that every scheduled object produced a result.

## Understand the output

Every run creates an isolated directory under `output/`.

### Final JSON files

| File | Contents |
|---|---|
| `data_<date-time>.json` | Successful standard and custom object counts |
| `tooling_<date-time>.json` | Successful Tooling API object counts |
| `skipped_<date-time>.json` | Objects that could not be counted and their reasons |
| `durations_<date-time>.json` | Query duration for every processed object |

### Excel workbook

`SF_Objects_<date-time>.xlsx` combines the same information into four worksheets:

- Data Objects
- Tooling Objects
- Skipped Objects
- Durations (Seconds)

Headers are frozen and filterable. Sort the record-count column from largest to
smallest to identify likely large-data-volume objects.

### Robot and Pabot reports

The top-level Robot report is written to the directory supplied with `-d`, usually
`results/`. Detailed Pabot worker logs are kept inside the run directory under
`pabot/results/`.

## Skip reasons

An unsupported query does not stop the scan. It is recorded in the skipped report
with a reason such as:

- `COUNT_NOT_SUPPORTED`
- `REQUIRES_WHERE_StatType`
- `INVALID_TYPE`
- `INSUFFICIENT_ACCESS`
- `REQUEST_LIMIT_EXCEEDED`
- `TIMEOUT`
- `TOOLING_DISCOVERY_FAILED`
- `WORKER_ERROR`
- `OTHER_ERROR`

Request limits, timeouts, discovery failures, worker errors, invalid CLI JSON,
expired sessions, and unknown CLI errors are operational failures. The scanner
finishes writing its reports and then fails by default so automation does not
mistake a partial scan for a complete one.

Review permission-related failures using the same Salesforce user that ran the
scan. Some Salesforce objects cannot support `COUNT()` regardless of permissions.

## Troubleshooting

### Salesforce CLI is not found

Run `sf --version`. If the command fails, install Salesforce CLI or add its
executable directory to `PATH`, then open a new terminal.

### The org alias is rejected

Check the session:

```bash
sf org display --target-org MyOrg
```

If it has expired, authenticate again with `sf org login web --alias MyOrg`.

### The scan is slower than expected

- Check whether Tooling counts are actually needed.
- Compare the number of completed artifacts over several minutes.
- Increase `PABOT_PROCESSES` gradually.
- Look for objects reaching the configured timeout.
- Run outside periods of heavy integration or deployment activity.

### Many objects report `REQUEST_LIMIT_EXCEEDED`

Stop increasing concurrency. Review the org's API usage, allow capacity to
recover, and run again with fewer workers.

### No final Excel workbook is created

Open the top-level `log.html` and inspect the Pabot result directory. The parent
run intentionally refuses to consolidate incomplete or unexpected worker
artifacts.

## Limitations

- Exact `COUNT()` queries can be slow for very large objects.
- Salesforce permissions determine which objects the authenticated user can see.
- Some objects require filters or do not support count queries.
- The scan consumes Salesforce API requests and is subject to org limits.
- Results are a point-in-time view; records can change while the scan is running.
- Tooling objects can overlap conceptually with data objects and are reported
  separately.

## CI and local validation

The CI-safe checks do not require a live Salesforce org:

```bash
pip install -r requirements-dev.txt
robot -d results-smoke ci/robot/smoke.robot
robot -d results-parallel ci/robot/parallel_smoke.robot
python -m unittest discover -s tests -v
robot --dryrun -d results-dryrun src/robot/orchestrator/scan.robot
ruff check src tests ci/fakes
robocop check src/robot ci/robot
```

A full scanner run requires Salesforce CLI authentication and the permissions of
the target user.
