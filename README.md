
# Salesforce Objects Scanner

A lightweight, robust Salesforce CLI utility to scan all queryable sObjects in an org and retrieve record counts per object.

Ideal for:
- Org health checks
- Storage usage analysis
- Large Data Volume (LDV) risk identification
- Data cleanup planning
- Migration / sandbox refresh preparation


Built with **Robot Framework** — easy to run, modify, extend, and integrate into CI/CD or scheduled jobs.

## Features

- Scans **all queryable sObjects** using `sf sobject list --json`
- Retrieves record count via `SELECT COUNT() FROM ObjectName` (data + Tooling API)
- Smart filtering: skips noisy/restricted objects (History, Feed, Share, ChangeEvent, Big Objects, etc.)
- Dynamic Tooling API discovery (`/tooling/sobjects/`) with fallback to static list
- Timeout protection + per-object dynamic timeouts (e.g., longer for `ConnectedApplication`)
- Detailed error classification & skip reasons (e.g. `COUNT_NOT_SUPPORTED`, `REQUIRES_WHERE_StatType`)
- Tracks duration per object + total runtime
- Outputs clean JSON + console summary (top counts, skipped objects)
- Cross-platform (Windows + Mac/Linux) — handles `sf.cmd` correctly

## Requirements

- **Salesforce CLI** (`sf`) installed and authenticated to your org  
  → `sf org login web --alias DeveloperOrg` (or your alias)
- **Robot Framework** 5.0+  
  `pip install robotframework`
- Python 3.8+ (Robot runs on Python)
- Libraries used: `OperatingSystem`, `Collections`, `Process`, `DateTime`, `String`, `json` (all built-in or standard)

No extra pip packages needed beyond Robot Framework itself.

## Installation

1. Clone or download the repository
2. Navigate to the folder containing `Support.robot` (and your test suite if separate)
3. (Optional) Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate   # Linux/Mac
   venv\Scripts\activate      # Windows
   pip install robotframework
   ```

## Usage

Run the Test:

```bash
robot --test Object_Scanner -d reports src/robot/tests/Test.robot
```

Or run directly if `Get All Object Record Counts` is the main keyword:

```bash
robot --loglevel INFO --outputdir results Support.robot
```

### Example Output (console)

```
Starting for org: DeveloperOrg
Output: results/salesforce_record_counts.json
Raw objects found: 1514
After filter: 892
Objects to process: 892

[1/892] 0.1% Counting: Account
[Standard]-[1/892] Account: 1245 (t=0.9s)
...

Querying Tooling API objects...
Discovering tooling objects dynamically...
Tooling objects to process: 28
[1/28] 3.6% Counting: ApexClass
[Tooling]-[1/28] ApexClass: 156 (t=1.2s)
...

Done! Results saved to: results/salesforce_record_counts.json
Total runtime: 12 minutes 45 seconds
```

### Output Files

- `results/salesforce_record_counts.json`  
  Structured JSON with:
  - `org_alias`
  - `generated_at`
  - `data_objects` → {ObjectName: count}
  - `tooling_objects` → {ObjectName: count}
  - `skipped_objects` → {ObjectName: reason}
  - `durations_seconds` → {ObjectName: seconds}

## Configuration

Edit these variables at the top of `Support.robot`:

```robotframework
${ORG_ALIAS}                    DeveloperOrg        # ← change to your alias
${INCLUDE_TOOLING}              ${TRUE}             # Set to ${FALSE} to skip Tooling API
${DISCOVER_TOOLING_OBJECTS}     ${TRUE}             # Dynamic vs static list
${DELAY_SECONDS}                0.1                 # Increase if hitting API limits
${MAX_QUERY_TIMEOUT_SECONDS}    120                 # Max per query
```

## Extending the Tool

Easy to customize:

- Add more objects to skip → edit `@{NON_COUNTABLE_OBJECTS}`, `@{COUNT_NOT_SUPPORTED_OBJECTS}`
- Change polling interval → `${POLL_INTERVAL_SECONDS}`
- Add CSV export → see example in comments or request it
- Run only specific objects → pass a list instead of full scan
- Schedule → cron job / Windows Task Scheduler → `robot Support.robot`

## Troubleshooting

| Problem                                   | Likely Cause                          | Fix |
|-------------------------------------------|----------------------------------------|-----|
| "Salesforce CLI not found"                | `sf` not in PATH                      | Install/update sf CLI |
| "Org alias not found"                     | Not logged in                         | `sf org login web --alias DeveloperOrg` |
| Long-running queries timeout              | Object is very large/slow             | Increase `${MAX_QUERY_TIMEOUT_SECONDS}` or add to `@{SLOW_OBJECTS}` |
| "No JSON found" or parse errors           | CLI output format changed             | Update `Safe Parse Sf Json` or check `sf --version` |
| Windows-specific failures                 | `sf.cmd` path issue                   | Ensure `sf` works in cmd.exe manually |

## License

MIT License (or your preferred open-source license)

Feel free to fork, contribute, or use in any project!

## Contributing

Pull requests welcome! Especially:
- Better skip reason patterns
- Retry logic for rate limits
- CSV / Excel export
- Parallel execution (with Pabot)

Questions or issues → open an issue or reach out.

Happy scanning!
