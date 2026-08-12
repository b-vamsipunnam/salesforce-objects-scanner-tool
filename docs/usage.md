# Usage Guide

This guide covers installation, configuration, outputs, performance, and common
problems. For the components and execution model, see
[Architecture](architecture.md).

## Install the scanner

You need Python 3.10 or newer, Salesforce CLI, and access to a Salesforce org.
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
| `VERBOSE_OBJECT_RESULTS` | No | `false` | Print each successful object count to the console and Pabot log |
| `SF_COMMAND_TIMEOUT_SECONDS` | No | `120` | Timeout for Salesforce CLI setup and discovery commands |
| `MAX_QUERY_TIMEOUT_SECONDS` | No | `120` | Timeout for a normal object query |
| `CONNECTEDAPP_TIMEOUT` | No | `180` | Extended timeout for known slow objects |
| `SF_TRANSIENT_RETRIES` | No | `2` | Retries for external-provider, request-limit, and unknown platform errors |
| `SF_RETRY_BACKOFF_SECONDS` | No | `2.0` | Initial retry delay; each subsequent delay doubles |
| `ALLOW_DISABLED_DATACLOUD` | No | `false` | Treat verified disabled Data Cloud access as an intentional expected skip |
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

Start with the default four workers. Increasing workers may reduce runtime after
validating Salesforce API capacity. Increase the value gradually; the following
command is an example configuration, not a performance guarantee:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable PABOT_PROCESSES:8 src/robot/orchestrator/scan.robot
```

More workers are not always faster. Salesforce API capacity, network latency,
local CPU, object query complexity, and repeated CLI startup all affect
throughput. Run during a quieter period and reduce concurrency if the scan
reports request-limit or transient service errors.

The worker count is fixed when Pabot starts. It cannot be changed during an active
run.

`PABOT_SHARDS_PER_PROCESS` controls how many balanced suites are queued per
worker. The default of `4` gives Pabot smaller work units so a few slow objects do
not leave other workers idle near the end of a scan.

### Performance and benchmarking

Runtime depends on discovered object count, Salesforce API capacity, CLI startup
overhead, query complexity, network latency, and worker count. More workers are
not automatically faster. Compare worker settings against the same org during a
similar activity window and stop increasing concurrency when request-limit or
transient service errors rise.

Use this template to record comparable runs. The project does not publish a
universal runtime expectation:

| Org Type | Objects Discovered | Data Counted | Tooling Counted | Workers | Runtime | Notes |
|---|---:|---:|---:|---:|---:|---|
| _Fill in_ | — | — | — | — | — | _API capacity, network conditions, and relevant context_ |

For a repeatable benchmark, run the same scan with 1, 2, 4, 8, and 16 workers,
record the results above, and retain the related `Skipped Objects` worksheet.

## Follow progress

By default, `VERBOSE_OBJECT_RESULTS` is false. The console shows scan progress,
skipped objects, operational failures, and the final summary without printing
every successful count. Set `--variable VERBOSE_OBJECT_RESULTS:true` when
detailed per-object output is useful for troubleshooting.

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable VERBOSE_OBJECT_RESULTS:true src/robot/orchestrator/scan.robot
```

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

```text
output/Run_<date-time>_<id>/
|-- json/
|   |-- data_<date-time>.json
|   |-- tooling_<date-time>.json
|   |-- skipped_<date-time>.json
|   |-- skipped_details_<date-time>.json
|   `-- durations_<date-time>.json
|-- pabot/
|   |-- artifacts/
|   |-- results/
|   |-- workers/
|   `-- pabot-console.log
`-- SF_Objects_<date-time>.xlsx
```

### Final JSON files

| File | Contents |
|---|---|
| `data_<date-time>.json` | Successful standard and custom object counts |
| `tooling_<date-time>.json` | Successful Tooling API object counts |
| `skipped_<date-time>.json` | Objects that could not be counted and their reasons |
| `skipped_details_<date-time>.json` | Sanitized Salesforce error code and message for each skipped object |
| `durations_<date-time>.json` | Query duration for every processed object |

### Excel workbook

`SF_Objects_<date-time>.xlsx` combines the same information into four worksheets:

- Data Objects
- Tooling Objects
- Skipped Objects
- Durations (Seconds)

Headers are frozen and filterable. Sort the record-count column from largest to
smallest to identify likely large-data-volume objects.
The `Skipped Objects` worksheet includes the classification reason and Salesforce
error details used to make that classification. Targeted redaction replaces
recognized authentication URLs, session IDs, authorization headers, and tokens
with stable `[REDACTED_...]` placeholders before persistence. Treat all external
error text as potentially sensitive and restrict access to scan artifacts.

#### Mandatory `Skipped Objects` review

Whoever runs the scanner is responsible for opening the generated Excel workbook
and reviewing **every row** in the `Skipped Objects` worksheet. This review is
required after every run, regardless of whether the Robot test passed or failed.

A passing run only confirms that the scanner found no unexpected operational
failure. It does not guarantee that every discovered object was counted. Before
using the workbook for an audit, migration, archival decision, or deletion:

1. Check every skipped object and its recorded reason.
2. Confirm that expected limitations, such as `COUNT_NOT_SUPPORTED`,
   `QUERY_NOT_SUPPORTED`, or `RESTRICTIVE_FILTER_REQUIRED`, are acceptable for
   the intended use.
3. Investigate permission, authentication, timeout, API-limit, discovery, and
   unknown errors rather than assuming the missing counts are zero.
4. Rerun the scan after correcting actionable issues, and retain the reviewed
   workbook with the related Robot report.

Do not represent the scan as complete until the `Skipped Objects` worksheet has
been reviewed and its omissions have been accepted by the responsible operator.

### Robot and Pabot reports

The top-level Robot report is written to the directory supplied with `-d`, usually
`results/`. Detailed Pabot worker logs are kept inside the run directory under
`pabot/results/`.

## Skip reasons

An unsupported query does not stop the scan. Expected limitations are recognized
only when the object identity, Salesforce error code, and message pattern match a
verified rule. Expected reasons include:

- `COUNT_NOT_SUPPORTED`
- `QUERY_NOT_SUPPORTED`
- `BIG_OBJECT_COUNT_UNSUPPORTED`
- `RESTRICTIVE_FILTER_REQUIRED`
- `DATACLOUD_INTENTIONALLY_DISABLED`

Everything else is operational by default, including unverified
`MALFORMED_QUERY`, `INVALID_TYPE`, `INSUFFICIENT_ACCESS`, and
`EXTERNAL_OBJECT_EXCEPTION` responses. External-provider, request-limit, and
unknown platform failures are retried before being recorded as operational.
The scanner finishes writing its reports and then fails so automation does not
mistake a partial scan for a complete one.

Keep `ALLOW_DISABLED_DATACLOUD` false unless Data Cloud is intentionally outside
the scope of the scan. When false, disabled Data Cloud access remains an
operational configuration or permission problem.

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
