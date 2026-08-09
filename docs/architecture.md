# Architecture

The scanner is a Robot Framework workflow built around Salesforce CLI. Robot
handles discovery, parallel work planning, query execution, result validation,
and report generation. Python is limited to small interoperability helpers and
the Excel writer.

## Execution flow

<p align="center">
  <img src="architecture.svg" width="900" alt="Parallel Salesforce Object Count Scanner architecture">
</p>

1. Validate the Salesforce CLI and authenticated org alias.
2. Discover standard, custom, and optionally Tooling API objects.
3. Deduplicate the object names and distribute them across balanced Robot suites.
4. Run those suites concurrently with Pabot.
5. Query every object with its own timeout and write one atomic JSON artifact.
6. Verify that every scheduled object produced exactly one valid artifact.
7. Consolidate counts, skips, durations, and operational failures.
8. Save JSON and Excel reports, then apply the scan quality gate.

When requested Tooling discovery fails, the scanner does not silently substitute
a partial object list. Data queries continue, the report records
`TOOLING_DISCOVERY_FAILED`, and the final quality gate fails. Tooling can be
omitted explicitly with `INCLUDE_TOOLING:false`; there is no fallback object list.

Each Pabot worker processes a batch of objects. This reuses worker processes and
avoids starting a separate Robot process for every object. The number of suites
is controlled by `PABOT_PROCESSES * PABOT_SHARDS_PER_PROCESS`, capped at the
number of objects.

## Component boundaries

| Component | Responsibility |
|---|---|
| `orchestrator/scan.robot` | Small executable entry point |
| `resources/keywords.robot` | Public workflow composition |
| `resources/configuration.resource` | Defaults and runtime normalization |
| `resources/salesforce.resource` | Salesforce discovery, queries, and error classification |
| `resources/parallel_execution.resource` | Balanced Pabot suites and artifact validation |
| `resources/reporting.resource` | Run directories, JSON reports, and Excel generation |
| `libraries/SfUtils.py` | Executable lookup and robust CLI JSON parsing |
| `libraries/ExcelWriter.py` | Formatted workbook creation |

## Run isolation

Every execution creates `output/Run_<date-time>_<id>/`. Generated worker suites,
Pabot logs, and per-object artifacts stay inside that directory. Processes use
their own captured output; they do not share a root-level stdout or stderr file.

Artifact names include the API family (`data` or `tooling`) and object name, so
the same name in both APIs cannot collide. A worker first writes a temporary file
and then moves it to its final path, preventing the parent from reading a partial
result.

## Failure model

Expected Salesforce limitations are recorded as skips, including objects that do
not support `COUNT()`, require a filter, or are inaccessible to the current user.
They do not fail the scan.

Infrastructure and session problems are different. Invalid JSON, expired
sessions, request-limit errors, timeouts, and unclassified CLI failures are
operational failures. Reports are written first so the evidence is retained;
the quality gate then fails the Robot run by default. Set
`FAIL_ON_OPERATIONAL_ERRORS:false` only when a best-effort report is explicitly
preferred.

Each batch converts unexpected per-object query exceptions into a `WORKER_ERROR`
artifact before moving to the next object. Invalid artifact schemas and artifact
write failures remain fatal because their results cannot be trusted.

## Outputs

The `json/` directory contains successful data counts, successful Tooling counts,
all skips, and per-object durations. The run root contains the formatted Excel
workbook. Robot's top-level report remains in the directory supplied with `-d`,
while detailed Pabot logs stay under the isolated run directory.

## Scaling safely

`PABOT_PROCESSES` controls simultaneous Salesforce queries.
`PABOT_SHARDS_PER_PROCESS` controls how many balanced suites are queued per
worker, which improves load balancing when object runtimes vary. Increase worker
count gradually: Salesforce API capacity and local CLI startup cost usually
become the limiting factors before CPU does.

The scanner performs one discovery pass and one count attempt per object. It does
not automatically retry failed queries, keeping API usage and runtime
predictable.

## Security

Authentication is delegated to Salesforce CLI. The repository stores no
passwords, tokens, or connected-app secrets. Runtime output is ignored by Git and
each scan uses the permissions of the authenticated Salesforce user.
