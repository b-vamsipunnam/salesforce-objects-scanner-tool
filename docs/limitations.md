# Limitations

The workbook is a count report, not a complete Salesforce assessment. Keep these
limits in mind when using it:

- Results depend on the authenticated user's object visibility and query access.
- Some Salesforce objects do not support an unfiltered `COUNT()` query.
- Counts can change while the scan is running because the objects are not counted
  at the same instant.
- The scanner uses ordinary queries rather than `queryAll`, so deleted and
  archived records may not be included.
- Every discovery and count request consumes Salesforce API capacity.
- Large or complex objects can take a long time to count.
- A count does not show storage use, record relationships, data quality, or how
  difficult an object will be to migrate.
- Interrupted scans cannot be resumed. A rerun starts with fresh discovery in a
  new output directory.

Only known Salesforce limitations are treated as expected skips. A new or
unmatched error is reported as an operational problem.

---

[Back to README](../README.md) | [Usage](usage.md)
