# Configuration

Pass settings with Robot Framework's `--variable NAME:value` option. Only
`ORG_ALIAS` is required.

| Variable                     |             Default   | Purpose                                                     |
|------------------------------|----------------------:|-------------------------------------------------------------|
| `ORG_ALIAS`                  |                 Empty | Authenticated Salesforce CLI alias                          |
| `PABOT_PROCESSES`            |                   `4` | Concurrent query workers                                    |
| `PABOT_SHARDS_PER_PROCESS`   |                   `4` | Balanced suites queued per worker                           |
| `INCLUDE_TOOLING`            |                `true` | Discover and count queryable Tooling API objects            |
| `VERBOSE_OBJECT_RESULTS`     |               `false` | Log every successful data-object count                      |
| `SF_COMMAND_TIMEOUT_SECONDS` |                 `120` | Setup and discovery command timeout                         |
| `MAX_QUERY_TIMEOUT_SECONDS`  |                 `120` | Normal per-object query timeout                             |
| `CONNECTEDAPP_TIMEOUT`       |                 `180` | Extended timeout for known slow objects                     |
| `POLL_INTERVAL_SECONDS`      |                 `1.0` | Interval used to check whether a query exceeded its timeout |
| `SF_TRANSIENT_RETRIES`       |                   `2` | Retries for configured transient failures                   |
| `SF_RETRY_BACKOFF_SECONDS`   |                 `2.0` | Initial exponential-backoff delay                           |
| `ALLOW_DISABLED_DATACLOUD`   |               `false` | Accept verified disabled Data Cloud as an expected skip     |
| `SCAN_OUTPUT_ROOT`           | `<repository>/output` | Root for isolated scan directories                          |
| `FAIL_ON_OPERATIONAL_ERRORS` |                `true` | Fail after reports are saved when operational errors remain |

`SF_TRANSIENT_RETRIES` sets the maximum number of retries. External and unknown
exceptions are retried only when the sanitized Salesforce message contains
evidence of a temporary failure. Deterministic feature-access, schema, and
method failures stop after the first attempt and remain operational failures.

Example:

```bash
robot -d results \
  --variable ORG_ALIAS:MyOrg \
  --variable PABOT_PROCESSES:8 \
  --variable INCLUDE_TOOLING:false \
  src/robot/orchestrator/scan.robot
```

Raise the worker count gradually. Network latency, CLI startup, object query
time, and the org's remaining API capacity all affect the result.

With `FAIL_ON_OPERATIONAL_ERRORS:false`, Robot can pass even when operational
errors were saved to `Skipped Objects`. Review that sheet before using the
counts.

---

[Back to README](../README.md) | [Usage](usage.md)
