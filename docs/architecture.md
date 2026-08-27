# Architecture

This is the technical overview of the scanner. See [Usage](usage.md) for the
user workflow and output format.

<p align="center">
  <img src="architecture.svg" width="900" alt="Salesforce Objects Scanner execution flow">
</p>

## Components

- Robot Framework controls configuration, discovery, batching, validation, and
  reporting.
- Salesforce CLI (`sf`) supplies the authenticated connection, lists regular
  data objects, calls the Tooling REST endpoint, and runs SOQL count queries.
- Pabot runs generated Robot suites in separate worker processes.
- `SfUtils.py` parses CLI JSON, classifies errors, and redacts common credential
  patterns.
- `ExcelWriter.py` creates the final workbook from consolidated JSON data.

## Execution flow

1. `scan.robot` normalizes settings, checks `ORG_ALIAS`, resolves the `sf`
   executable, and verifies the saved CLI session.
2. The parent suite creates a unique run directory.
3. `sf sobject list` returns data object names. If Tooling is enabled, the
   scanner calls `/services/data/v<version>/tooling/sobjects/` and keeps entries
   marked as queryable.
4. Object names are deduplicated and assigned round-robin to generated Robot
   suites.
5. Pabot starts the suites. Each worker runs `SELECT COUNT() FROM <object>` with
   `sf data query` and applies the per-object timeout and retry rules.
6. Each completed query writes one JSON artifact. Data and Tooling identities
   are kept separate when their object names match.
7. The parent validates all expected artifacts, writes the five final JSON files
   and Excel workbook, and then applies the scan-quality check.

Tooling discovery has no fallback object list. If discovery fails, data object
work continues and `TOOLING::DISCOVERY` is added to skipped results.

## Parallel model

The scanner generates at most
`PABOT_PROCESSES * PABOT_SHARDS_PER_PROCESS` suites, capped by the number of
objects. Each suite processes its assigned batch sequentially; Pabot runs up to
`PABOT_PROCESSES` suites at once. See [Configuration](configuration.md) for
defaults and tuning guidance.

## Result integrity

Workers write each artifact to a temporary file and then move it to its final
`.json` path. Before reporting, the parent checks that:

- The number of artifacts matches the scheduled object count
- Every expected data or Tooling object has one artifact
- Required fields and types are valid
- Successful counts are non-negative integers
- Skipped entries have no count

Pabot or artifact validation failures stop workbook creation. Query-level
operational errors are different: available reports are written first, and the
final quality check then fails by default.

## Error model

Verified Salesforce limitations are expected skips. These include unsupported
counts or queries, Big Object aggregate restrictions, required filters, and an
explicitly allowed disabled Data Cloud response. Other failures are operational.

`REQUEST_LIMIT_EXCEEDED` is retryable. Configured external and unknown errors
are retried only when their sanitized message indicates a temporary problem.
Retry delays use exponential backoff. Timeouts and deterministic failures are
not retried.

## Main files

| File                                              | Responsibility |
|---------------------------------------------------|----------------|
| `src/robot/orchestrator/scan.robot`               | Command entry point |
| `src/robot/resources/keywords.robot`              | Parent workflow |
| `src/robot/resources/configuration.resource`      | Defaults and validation |
| `src/robot/resources/salesforce.resource`         | CLI calls, queries, timeouts, and error classification |
| `src/robot/resources/parallel_execution.resource` | Suite generation, workers, and artifact validation |
| `src/robot/resources/reporting.resource`          | Run directories and final reports |
| `src/robot/libraries/SfUtils.py`                  | CLI parsing, classification, and redaction |
| `src/robot/libraries/ExcelWriter.py`              | Workbook generation |

Return to the [README](../README.md) or see
[Troubleshooting](troubleshooting.md) for operational fixes.
