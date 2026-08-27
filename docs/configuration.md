# Configuration

Only `ORG_ALIAS` is required. Every other setting is optional and has a default.
Pass a setting to Robot Framework as `--variable NAME:value`.

## Required setting

| Variable    | Default | Purpose                               |
|-------------|---------|---------------------------------------|
| `ORG_ALIAS` | Empty   | Salesforce CLI alias for the org to scan |

The alias must already work with Salesforce CLI. See
[Authentication](authentication.md).

## Scan and output settings

| Variable                     | Default                    | Purpose |
|------------------------------|----------------------------|---------|
| `INCLUDE_TOOLING`            | `true`                     | Include queryable Tooling API objects |
| `VERBOSE_OBJECT_RESULTS`     | `false`                    | Log every successful data and Tooling object count |
| `ALLOW_DISABLED_DATACLOUD`   | `false`                    | Treat one verified disabled Data Cloud response as an expected skip |
| `SCAN_OUTPUT_ROOT`           | `<command directory>/output` | Parent directory for isolated scan runs |
| `FAIL_ON_OPERATIONAL_ERRORS` | `true`                     | Fail after saving reports when operational skipped results remain |
| `SF_CLI`                     | `sf`                       | Salesforce CLI executable name or path |

Use `true` or `false` for Boolean settings. `SCAN_OUTPUT_ROOT` defaults to an
`output` directory under the directory where the Robot command starts.

## Parallel worker settings

| Variable                   | Default | Purpose |
|----------------------------|--------:|---------|
| `PABOT_PROCESSES`          |     `4` | Maximum concurrent Pabot worker processes |
| `PABOT_SHARDS_PER_PROCESS` |     `4` | Number of object batches queued per process |

Pabot is the Robot Framework parallel runner used by this project. It runs
several isolated batches at once. More processes can increase Salesforce API
pressure and do not guarantee a shorter run. `PABOT_PROCESSES` and
`PABOT_SHARDS_PER_PROCESS` must both be greater than zero.

## Timeout and retry settings

| Variable                     | Default | Purpose |
|------------------------------|--------:|---------|
| `SF_COMMAND_TIMEOUT_SECONDS` |   `120` | Timeout for CLI checks and object discovery |
| `MAX_QUERY_TIMEOUT_SECONDS`  |   `120` | Timeout for one normal object query |
| `CONNECTEDAPP_TIMEOUT`       |   `180` | Query timeout for `ConnectedApplication` |
| `POLL_INTERVAL_SECONDS`      |   `1.0` | How often a worker checks a running query |
| `SF_TRANSIENT_RETRIES`       |     `2` | Maximum retries after the first query attempt |
| `SF_RETRY_BACKOFF_SECONDS`   |   `2.0` | Delay before the first retry, in seconds |

Retry delays double after each retry. `REQUEST_LIMIT_EXCEEDED` is retryable.
External and unknown errors are retried only when the sanitized Salesforce
message shows evidence of a temporary problem. Known deterministic failures are
not retried. Timeouts are not retried.

Timeouts and the poll interval must be greater than zero. Retry values cannot be
negative.

## Examples

Run with all defaults:

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

Exclude Tooling API objects:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable INCLUDE_TOOLING:false src/robot/orchestrator/scan.robot
```

Use two worker processes and a four-minute object timeout:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable PABOT_PROCESSES:2 --variable MAX_QUERY_TIMEOUT_SECONDS:240 src/robot/orchestrator/scan.robot
```

`ALLOW_DISABLED_DATACLOUD:true` does not enable or disable Data Cloud. It only
changes one verified disabled-feature response from an operational failure to an
expected skip. Use it only when Data Cloud is intentionally outside the scan.

`FAIL_ON_OPERATIONAL_ERRORS:false` allows the final Robot quality check to pass
when operational errors remain in `Skipped Objects`. It does not create missing
counts, and it does not suppress setup, Pabot, artifact, or workbook failures.

See [Usage](usage.md) for output details and
[Troubleshooting](troubleshooting.md) for choosing settings after a failure.
