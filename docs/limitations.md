# Limitations

The output workbook is a count report, not a complete Salesforce assessment.

## What a count means

A successful count is the result of `SELECT COUNT()` for one object at one point
during the scan.

- The result is limited by the authenticated user's object access and record
  visibility.
- Objects are counted at different times, so records can change between one
  count and the next.
- The scanner uses an ordinary query, not `queryAll`. Deleted or archived records
  may therefore be absent.
- A count does not measure storage use, relationships, data quality, or migration
  effort.

Do not use the workbook as a storage report or as proof that an org is ready to
migrate.

## Skipped objects

A skipped object was discovered, but it did not return a successful count.
Salesforce objects do not all support the same query operations. Known
unsupported counts, unsupported queries, Big Object aggregate restrictions, and
queries that require a filter are treated as expected skips.

Query-time authentication, permission, timeout, API-limit, malformed-response,
and unknown errors are operational problems. By default, the scanner writes
available reports and then fails when operational skipped results remain. A
startup or discovery failure can stop the scan before a workbook is created.
Expected skips can still appear in a successful Robot Framework run.

A successful Robot Framework run does not mean every discovered object was
countable. A missing count is not zero.

## Discovery and permissions

The scanner starts with the object list returned by Salesforce CLI. It does not
use a fixed list. Objects that the org or authenticated user does not expose to
that command cannot appear in the report.

The same user's feature licenses, object permissions, and record visibility
affect each query. Two users can therefore get different inventories or counts
from the same org.

## External objects

External objects do not always support an unfiltered aggregate query. Salesforce
can also return an external-object error when the underlying service or feature
is unavailable. The scanner retries only configured errors that contain
evidence of a temporary problem. Any external object without a successful
result remains skipped; it is not counted as zero.

## Data Cloud

Data Cloud-related objects can be present in discovery even when the org feature
or authenticated user cannot query them. By default, a disabled Data Cloud error
is an operational problem.

`ALLOW_DISABLED_DATACLOUD:true` changes only one verified disabled-feature
response into an expected skip. It does not enable Data Cloud, remove those
objects from discovery, or create missing counts. Use it only when Data Cloud is
intentionally outside the assessment.

## Tooling API objects

Tooling API objects represent Salesforce setup and development information, not
ordinary business records. Their availability depends on the org and the
authenticated user. Tooling discovery can fail even when the data object
scan succeeds. Disable it with `INCLUDE_TOOLING:false` when Tooling objects are
not part of the assessment.

## Operational limits

- Discovery and count requests consume Salesforce API capacity.
- Large or complex objects can take longer than the configured timeout.
- More Pabot workers do not guarantee a faster scan and can increase API
  pressure.
- Interrupted scans cannot be resumed. A rerun performs fresh discovery and
  creates a new output directory.

See [Usage](usage.md) for reviewing skipped rows and
[Configuration](configuration.md) for the settings mentioned here.
