# Troubleshooting

Start with `results/log.html`. If a run directory was created, also inspect its
`pabot/pabot-console.log` and `pabot/results/` directory.

## `robot` is not found

**Likely cause:** The virtual environment is not active, or the requirements
were not installed in it.

**Fix:** Activate the environment from the repository root and reinstall the
runtime requirements:

```bash
python -m pip install -r requirements.txt
robot --version
```

Use the activation command for your operating system in
[Installation](installation.md#3-create-a-virtual-environment).

## `sf` is not found

**Likely cause:** Salesforce CLI is not installed or its directory is missing
from `PATH`.

**Fix:** Run:

```bash
sf --version
```

If the command is not recognized, install Salesforce CLI or add its executable
directory to `PATH`. Open a new terminal after the change and run the version
command again.

## PowerShell blocks a script

**Symptom:** PowerShell says that `Activate.ps1` or `sf.ps1` cannot be loaded
because running scripts is disabled.

**Likely cause:** The current PowerShell execution policy blocks local scripts.

**Fix:** You can use Windows Command Prompt without changing the policy:

```bat
venv\Scripts\activate.bat
sf.cmd --version
sf.cmd org login web --alias MyOrg
```

If `sf` also needs the `.cmd` form when Robot starts it, run:

```bat
robot -d results --variable ORG_ALIAS:MyOrg --variable SF_CLI:sf.cmd src/robot/orchestrator/scan.robot
```

## The org alias is rejected

**Likely cause:** The alias is misspelled, was saved under a different name, or
its session expired.

**Fix:** Check it outside Robot:

```bash
sf org display --target-org MyOrg
```

If the session has expired, sign in again with:

```bash
sf org login web --alias MyOrg
```

Use the same alias in `--variable ORG_ALIAS:MyOrg`.

## Objects fail with permission errors

**Likely cause:** The authenticated user lacks API access, object read access,
record visibility, or access to a feature used by that object.

**Fix:** Confirm the user requirements in [Authentication](authentication.md)
with a Salesforce administrator. Rerun the scan after the user or org access is
corrected. Do not treat the affected rows as zero.

## Tooling discovery fails

**Likely cause:** The org or user cannot access the Tooling REST endpoint, the
CLI request failed, or discovery returned no queryable Tooling objects.

**Fix:** Check the Salesforce response in the Robot log. The data object scan
continues, but `TOOLING::DISCOVERY` is added to skipped results and the default
quality check fails. If Tooling objects are outside your scope, run a data-only
scan:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable INCLUDE_TOOLING:false src/robot/orchestrator/scan.robot
```

## The scan appears to stop making progress

**Likely cause:** Successful object results are quiet by default, or a few object
queries are still running.

**Fix:** Open the current run's `pabot/pabot-console.log` and check whether new
files are appearing under `pabot/artifacts/`. If files continue to appear, the
workers are making progress. After a completed run, use `Durations (Seconds)` to
identify slow objects.

Enable per-object worker messages in `pabot-console.log` on the next run if
needed:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable VERBOSE_OBJECT_RESULTS:true src/robot/orchestrator/scan.robot
```

## Object queries time out

**Likely cause:** An object query took longer than
`MAX_QUERY_TIMEOUT_SECONDS`. `ConnectedApplication` has its own
`CONNECTEDAPP_TIMEOUT`.

**Fix:** Check `Durations (Seconds)` and the Salesforce error details first. If
the query only needs more time, increase the appropriate timeout for the next
run. For example:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable MAX_QUERY_TIMEOUT_SECONDS:240 src/robot/orchestrator/scan.robot
```

Do not increase a timeout to hide an authentication, permission, or API-limit
error.

## Many queries hit `REQUEST_LIMIT_EXCEEDED`

**Likely cause:** The org does not have enough remaining API capacity for the
current request rate.

**Fix:** Wait for API capacity to recover and rerun with fewer processes:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable PABOT_PROCESSES:2 src/robot/orchestrator/scan.robot
```

Adding workers or retries usually increases the request pressure.

## No workbook was created

**Likely cause:** Setup or Pabot failed, worker artifacts were incomplete, or
Excel generation failed.

**Fix:** Start with `results/log.html`, then check `pabot/pabot-console.log` and
`pabot/results/` inside the run directory. Fix the first reported error and start
a new scan. Do not copy partial artifacts into another run.

## Data Cloud is disabled

**Likely cause:** Salesforce returned the specific disabled Data Cloud response,
either because the feature is not available or the user cannot access it.

**Fix:** If Data Cloud is required, ask a Salesforce administrator to check the
org feature and user access. If it is intentionally outside the scan, rerun with:

```bash
robot -d results --variable ORG_ALIAS:MyOrg --variable ALLOW_DISABLED_DATACLOUD:true src/robot/orchestrator/scan.robot
```

This setting accepts only the verified disabled-feature response. It does not
enable Data Cloud or produce counts for those objects.

## Robot passes but the workbook has skipped objects

**Likely cause:** Salesforce returned a known limitation, such as an unsupported
`COUNT()` query or a required filter. These are expected skips and do not fail
the default quality check.

**Fix:** Review every skipped row and confirm that the missing count is
acceptable for the purpose of the scan. A missing count is not zero. See
[Limitations](limitations.md) for interpretation guidance.
