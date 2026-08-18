# Troubleshooting

## `sf` is not found

Run:

```bash
sf --version
```

If the command is not recognized, install Salesforce CLI or add its executable
directory to `PATH`. Open a new terminal after changing `PATH`.

## The org alias is rejected

Check the alias outside Robot:

```bash
sf org display --target-org MyOrg
```

If the session has expired, sign in again with:

```bash
sf org login web --alias MyOrg
```

## Tooling discovery fails

The data-object scan will continue, but `TOOLING::DISCOVERY` will appear in the
skipped results and the run will fail at the end. Check the Salesforce message
in the Robot log. If Tooling objects are not needed, run again with
`INCLUDE_TOOLING:false`.

## The scan takes longer than expected

Check `Durations (Seconds)` and the files under `pabot/artifacts/` to see whether
work is still completing. A few slow objects can keep a run open after most
counts are finished.

If Tooling objects are outside your scope, disable them. If the org has API
capacity available, try a modest increase to `PABOT_PROCESSES`. Compare one
change at a time; more processes do not always reduce the total runtime.

## Many queries hit `REQUEST_LIMIT_EXCEEDED`

Wait for API capacity to recover and rerun with fewer processes. Adding workers
or retries usually makes this problem worse.

## No workbook was created

Start with the top-level `log.html`, then check `pabot/results/` inside the run
directory. The workbook is not built if Pabot fails or if worker artifacts are
missing, duplicated, or malformed.

The run directory is still useful for diagnosis. Do not copy its partial JSON
artifacts into another run.

## Robot passes but the workbook has skipped objects

This is normal for known Salesforce query limitations. Robot only fails for
errors classified as operational. Review every skipped row and confirm that the
missing count is acceptable for the purpose of the scan.

---

[Back to README](../README.md) | [Usage](usage.md)
