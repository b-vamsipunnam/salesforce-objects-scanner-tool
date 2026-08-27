# Usage

Complete [Installation](installation.md) and [Authentication](authentication.md)
first. Keep the virtual environment active and run commands from the repository
root.

## Run the default scan

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

Replace `MyOrg` with your authenticated Salesforce CLI alias. The default scan
includes Salesforce data objects and queryable Tooling API objects. The
Tooling API exposes setup and development information rather than ordinary
business records.

At the start, the console confirms the CLI path, org alias, output workbook path,
and discovery totals. Pabot then runs object batches in parallel. Detailed
worker messages are written to `pabot/pabot-console.log` inside the current run.
The console prints successful and skipped totals when the batches finish.

To exclude Tooling objects, change worker counts, enable verbose results, or
adjust a timeout, use the examples in [Configuration](configuration.md).

## Find the output

Each scan creates a new directory. The full layout is:

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

A completed object creates a JSON file under `pabot/artifacts/`, so the number of
files there gives a rough view of progress. Do not move, edit, or delete a run
directory while the scan is active.

The `-d results` option sends Robot Framework's `log.html`, `report.html`, and
`output.xml` files to `results/`. These files describe the Robot run; the scanner
results remain under `output/`.

## Read the workbook

The Excel output workbook has four sheets:

| Sheet                 | Contents |
|-----------------------|----------|
| `Data Objects`        | Successful counts for standard and custom Salesforce objects |
| `Tooling Objects`     | Successful counts for Tooling API objects |
| `Skipped Objects`     | Objects without a count, a classified reason, and sanitized Salesforce details |
| `Durations (Seconds)` | Recorded query time for each object |

The final files under `json/` separate the same successful counts, skipped
reasons, skipped details, and durations for use by scripts.

## Review the skipped objects

A skipped object is one that was discovered but did not produce a successful
count. Check every row in `Skipped Objects`, even when Robot Framework reports a
passing run.

Known Salesforce restrictions, such as an object that does not support
`COUNT()` or requires a filter, are expected skips. Authentication failures,
permission problems, API limits, timeouts, and unknown errors are operational
problems. With the default settings, the scanner saves reports before failing
its final quality check for operational problems.

For each skipped row:

1. Read the reason and Salesforce message.
2. Decide whether the object is genuinely outside the scope of the review.
3. Fix authentication, permission, limit, or timeout problems and run the scan
   again when needed.
4. Keep the reviewed workbook with the matching Robot log.

Do not report a skipped object as having zero records. A successful Robot
Framework run does not mean every discovered object was countable.

## Protect the output

Captured errors are sanitized for common credential patterns, but the workbook,
JSON files, and Robot logs can still contain object names, counts, org URLs, and
Salesforce error details. Treat the entire run as sensitive org information.

See [Troubleshooting](troubleshooting.md) if a scan stops before creating the
workbook. Read [Limitations](limitations.md) before using the counts for cleanup,
migration, or storage decisions.
