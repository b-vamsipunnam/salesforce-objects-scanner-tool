# Salesforce Objects Scanner

Salesforce Objects Scanner finds the Salesforce objects available to a user,
counts their records where Salesforce allows it, and saves the results as an
Excel workbook and JSON files.

It is intended for Salesforce administrators, developers, and migration teams
who need a starting inventory for cleanup or migration planning. A Salesforce
object is similar to a database table: it stores records such as accounts,
contacts, or custom business data. The scanner reads from Salesforce but does
not change org data.

## Before you start

You need:

- [Git](https://git-scm.com/downloads), unless you download the repository as a
  ZIP file
- [Python](https://www.python.org/downloads/) 3.10 or later
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli),
  the `sf` command-line program used to sign in and send requests to Salesforce
- Access to a Salesforce org through a user who can use the API and read the
  objects you want to count

See [Installation](docs/installation.md) if any of these tools are not ready.

## Quick start

Run these commands in a terminal.

### 1. Download the project and create a virtual environment

```bash
git clone https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool.git
cd salesforce-objects-scanner-tool
python -m venv venv
```

A virtual environment keeps this project's Python packages separate from other
projects. Activate it before installing anything.

On Windows PowerShell:

```powershell
.\venv\Scripts\Activate.ps1
```

On Windows Command Prompt:

```bat
venv\Scripts\activate.bat
```

On macOS or Linux:

```bash
source venv/bin/activate
```

### 2. Install the scanner

```bash
python -m pip install -r requirements.txt
```

The command installs Robot Framework, Pabot, and the Excel-writing library in
the virtual environment.

### 3. Sign in to Salesforce

```bash
sf org login web --alias MyOrg
```

A Salesforce org is a Salesforce environment, such as a production org or
sandbox. The command opens a browser for sign-in. `MyOrg` is an org alias: a
short local name for that saved login. You can choose another name, but use the
same name in the remaining commands.

Confirm that the alias works:

```bash
sf org display --target-org MyOrg
```

The command should show the selected org without an authentication error. Its
output contains sensitive connection information, so do not share it.

### 4. Run the scan

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

An object scan asks Salesforce for object names and then runs
`SELECT COUNT()` for each name. The console shows the output workbook path before
the count work begins and prints a summary when the run ends.

## Results

Each scan creates a directory under `output/`:

```text
output/Run_<date-time>_<id>/
|-- json/
|-- pabot/
`-- SF_Objects_<date-time>.xlsx
```

The `.xlsx` file is the output workbook. `Data Objects` contains successful
counts for standard and custom Salesforce objects. `Tooling Objects` contains
successful counts for development and setup metadata exposed by Salesforce's
Tooling API; these objects are included by default. The workbook also contains
skipped objects and query durations. The `json/` directory holds the same report
data for scripts. Robot Framework writes its technical log and report to
`results/`.

A skipped object is an object that Salesforce discovered but the scanner could
not count. Always review every row in the workbook's `Skipped Objects` sheet.
A successful Robot Framework run does not mean every discovered object was
countable. A missing count is not zero.

Common credential patterns are redacted from captured errors, but the output can
still contain sensitive information about your Salesforce org. Store and share
the run directory accordingly. See [Usage](docs/usage.md) for every output file
and [Limitations](docs/limitations.md) before using the counts in an assessment.

## How it works

<p align="center">
  <a href="docs/architecture.md">
    <img src="docs/architecture.svg" width="900" alt="Salesforce Objects Scanner execution flow">
  </a>
</p>

Salesforce CLI discovers objects and runs the `SELECT COUNT()` queries. Robot
Framework controls the workflow and reporting, while Pabot, its parallel runner,
runs isolated object batches. See [Architecture](docs/architecture.md) for
details.

## Documentation

| Guide                                      | What it covers                                |
|--------------------------------------------|-----------------------------------------------|
| [Installation](docs/installation.md)       | Prerequisites and local setup                 |
| [Authentication](docs/authentication.md)   | Salesforce CLI login and permissions          |
| [Configuration](docs/configuration.md)     | Robot variables, defaults, and timeouts       |
| [Usage](docs/usage.md)                     | Running a scan and reading its output         |
| [Architecture](docs/architecture.md)       | Execution flow and component responsibilities |
| [Troubleshooting](docs/troubleshooting.md) | Common failures and practical fixes           |
| [Limitations](docs/limitations.md)         | What the counts do and do not represent       |

See [CONTRIBUTING.md](CONTRIBUTING.md) to work on the project. This project uses
the [MIT License](LICENSE).
