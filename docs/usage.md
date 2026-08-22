# Usage

Finish the [installation](installation.md) and sign in with Salesforce CLI as
described in [authentication](authentication.md). Run the scanner from the
repository root:

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

`MyOrg` must be an alias that works with `sf org display --target-org MyOrg`.

## Choosing what to scan

By default, the scanner includes data objects and queryable Tooling API objects.
For a data-only scan, turn Tooling off:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable INCLUDE_TOOLING:false src/robot/orchestrator/scan.robot
```

Successful counts are not printed one by one unless verbose output is enabled:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable VERBOSE_OBJECT_RESULTS:true src/robot/orchestrator/scan.robot
```

Other settings, including worker count and timeouts, are listed in
[Configuration](configuration.md).

## Watching a run

The console shows discovery totals, retries, skipped objects, and the final
summary. A completed object also leaves an artifact in the current run:

```text
output/Run_<date-time>_<id>/pabot/artifacts/
```

The number of artifacts is a quick indication of progress. Do not move, edit, or
delete the run directory until Robot finishes.

## Output files

The output for one run looks like this:

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

The Excel workbook has four sheets:

- `Data Objects` contains successful data-object counts.
- `Tooling Objects` contains successful Tooling API counts.
- `Skipped Objects` lists objects that could not be counted, along with the
  classified reason and sanitized Salesforce details.
- `Durations (Seconds)` shows how long each object query took.

The JSON files contain the same information for scripts or later comparison.
Robot's `log.html` and `report.html` are written to the directory passed with
`-d`, which is `results/` in the examples above.

## Review the skipped objects

Check every row in `Skipped Objects`, even when Robot reports a passing run.
Some Salesforce objects do not support `COUNT()` or require a filter. Those
known cases are allowed to pass. Authentication, permissions, API limits,
timeouts, and unrecognized errors still need attention.

For each skipped row:

1. Read the reason and Salesforce message.
2. Decide whether the object is genuinely outside the scope of the review.
3. Fix authentication, permission, limit, or timeout problems and run the scan
   again when needed.
4. Keep the reviewed workbook with the matching Robot log.

Do not report a skipped object as having zero records.

## Adjusting parallelism

The default is four Pabot processes. Increase `PABOT_PROCESSES` in small steps
and compare runs against the same org. More workers can make a scan slower or
produce more `REQUEST_LIMIT_EXCEEDED` errors when API capacity is tight.

`PABOT_SHARDS_PER_PROCESS` controls how many batches are queued per process. The
default of four is usually a reasonable starting point when object query times
vary widely.

See [Troubleshooting](troubleshooting.md) if a scan stops before creating the
workbook.

---

[Back to README](../README.md) | [Architecture](architecture.md)
