# Salesforce Objects Scanner

**Quickly understand your Salesforce org’s data footprint.**

Scan all queryable sObjects, get accurate record counts, identify Large Data Volume (LDV) risks, and generate ready-to-analyze Excel reports — all with safe, timeout-protected execution.

> Enterprise-grade Salesforce org analysis tool for data visibility, LDV detection, and migration planning.
> Designed to handle Salesforce orgs with hundreds to thousands of objects while maintaining predictable execution and structured outputs.
---

## Built With

[![Robot Framework](https://img.shields.io/badge/Robot%20Framework-5.0+-orange?style=flat&logo=robotframework&logoColor=white)](https://robotframework.org/)
[![Python](https://img.shields.io/badge/Python-3.8+-blue?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![Salesforce CLI](https://img.shields.io/badge/Salesforce%20CLI-sf-00A1E0?style=flat&logo=salesforce&logoColor=white)](https://developer.salesforce.com/tools/sfdxcli)
[![Node.js](https://img.shields.io/badge/Node.js-18.20.4-339933?style=flat&logo=node.js&logoColor=white)](https://nodejs.org/)
[![CI](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/actions/workflows/robot-ci.yml/badge.svg)](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/actions)
[![Release](https://img.shields.io/github/v/release/b-vamsipunnam/salesforce-objects-scanner-tool?style=flat&color=orange&logo=github&logoColor=white)](https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat&logo=open-source-initiative&logoColor=white)](https://opensource.org/licenses/MIT)

---

## Introduction

The Salesforce Objects Scanner is an automation-driven framework that analyzes your Salesforce org’s data footprint by retrieving accurate record counts across all queryable objects.

Built using **Robot Framework + Salesforce CLI**, the tool provides a structured and reliable way to assess org size, identify large objects (LDV risks), and support migration planning.

Native Salesforce tools offer limited visibility into object-level data size and lack a unified way to analyze all sObjects. This tool addresses those gaps by delivering comprehensive, structured reporting across your entire org.

---

## When to Use This Tool

This tool is ideal when you need to:

- Analyze Salesforce org data volume  
- Identify large objects (LDV risk)  
- Perform storage and usage audits  
- Prepare for data migration or sandbox refresh
- Plan data cleanup initiatives  

---

## Why This Exists

Native Salesforce tools have limitations:

- No unified way to scan all objects  
- Limited visibility into object-level data size  
- No structured reporting across all sObjects  
- Manual and time-consuming analysis

---

## Key Features

- Scans all queryable objects using `sf sobject list --json`
- Executes `SELECT COUNT()` queries across standard and Tooling API objects
- Smart filtering of noisy and unsupported objects
- Dynamic Tooling API discovery with fallback
- Timeout-controlled execution (prevents long-running failures)
- Robust JSON parsing (handles CLI output inconsistencies)
- Structured skip classification:
  - COUNT_NOT_SUPPORTED  
  - REQUIRES_WHERE  
  - INVALID_TYPE / restricted objects  
- Per-object execution time tracking
- Generates structured JSON outputs and Excel report
- Clear execution summary with success and skip metrics
---

## Architecture Overview

**Execution model:**

- **Control Layer:** Salesforce CLI (metadata + queries)  
- **Orchestration Layer:** Robot Framework (logic + workflow)  
- **Execution Layer:** Process-based execution with timeout protection  
- **Output Layer:** JSON artifacts + Excel report  

This design ensures predictable, scalable, and observable execution. 
Each execution creates an isolated run folder to ensure clean, reproducible outputs.

<p align="center">
  <img src="docs/architecture.png" width="700">
</p>

## Technology Stack

- Robot Framework  
- Salesforce CLI (sf)  
- Python  
- Custom ExcelWriter utility  

---

## Quick Start

### Prerequisites
- Python 3.8+
- Salesforce CLI (`sf`)
- Robot Framework and dependencies

### Installation

```bash
git clone https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool.git
cd salesforce-objects-scanner-tool
python -m venv venv

# Windows:
venv\Scripts\activate

# macOS/Linux:
source venv/bin/activate

pip install -r requirements.txt
```

--- 

## Run the Scanner

1. Authenticate to your Salesforce org:
   ```bash
   sf org login web --alias MyOrg
   ```
2. Configure org alias
   Before running, update the ${ORG_ALIAS} variable in: `src/robot/orchestrator/scan.robot`
   ```robot
   *** Variables ***
   ${ORG_ALIAS}    MyOrg
   ```
4. Run:
   ```bash
   robot --test Object_Scanner -d results src/robot/orchestrator/scan.robot
   ```
5. Check outputs:
   ```text
   JSON files     : output/
   Excel report   : output/SF_Objects_<datetime>.xlsx
   Logs & reports : results/
   ```   

## Project Structure

```
salesforce-objects-scanner/
├── .github/
│   ├── workflows/
│   │   └── robot-ci.yml                                   # GitHub Actions CI
│   └── PULL_REQUEST_TEMPLATE.md                           # Pull request template
├── ci/
│   └── robot/
│       └── smoke.robot
├── output/                                                # Generated runtime outputs
│   └── Run_<datetime>_<uuid>/                             # Isolated folder for each execution
│       ├── json/                                          # Structured JSON artifacts
│       │   ├── data_<datetime>.json
│       │   ├── tooling_<datetime>.json
│       │   ├── skipped_<datetime>.json
│       │   └── durations_<datetime>.json
│       └── SF_Objects_<datetime>.xlsx                     # Consolidated Excel report
├── results/                                               # Robot Framework execution logs
│   ├── log.html
│   ├── output.xml
│   └── report.html
├── src/
│   └── robot/
│       ├── libraries/
│       │   └── ExcelWriter.py
│       ├── orchestrator/
│       │   └── scan.robot
│       └── resources/
│           └── keywords.robot                             # Core workflow and keywords
├── .gitignore
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── README.md
├── requirements.txt
└── SECURITY.md
```
---

## Configuration

| Variable                       | Default Value | Description                          |
|--------------------------------|---------------|--------------------------------------|
| `${ORG_ALIAS}`                 | MyOrg         | Target org alias                     |
| `${INCLUDE_TOOLING}`           | ${TRUE}       | Include Tooling API objects          |
| `${DISCOVER_TOOLING_OBJECTS}`  | ${TRUE}       | Dynamically discover Tooling objects |
| `${DELAY_SECONDS}`             | 0.1           | Delay between queries                |
| `${MAX_QUERY_TIMEOUT_SECONDS}` | 120           | Per-query timeout                    |

---

## Output Files

### JSON Files

| File                        | Purpose                                |
|-----------------------------|----------------------------------------|
| `data_<datetime>.json`      | Record counts for standard objects     |
| `tooling_<datetime>.json`   | Record counts for tooling objects      |
| `skipped_<datetime>.json`   | Skipped objects with reasons           |
| `durations_<datetime>.json` | Execution time per object              |

### Excel Report

| File                          | Purpose                              |
|-------------------------------|--------------------------------------|
| `SF_Objects_<datetime>.xlsx`  | Consolidated report for analysis     |

---

## Example Execution

Typical console output:

```text
Starting for org: DeveloperOrg
Raw objects found: 1500+
After filter: 800+

[Standard]-[1/800] Account: 1245 (t=0.9s)

Querying Tooling API objects...

===== SUMMARY =====
Success(Data): 780
Success(Tooling): 28
Skipped: 22
=====================
```
---

## Execution Details

* Each object is queried independently with timeout protection
* Skipped objects are classified and logged with clear reasons
* Execution time is tracked per object
* Results are stored in structured JSON and Excel formats

---

## Limitations & Trade-offs

* COUNT() queries may be slow for large datasets
* Some objects require WHERE clauses and are skipped
* Dependent on Salesforce CLI output format
* Currently optimized for Windows environments
* Very large orgs may take 10–30+ minutes depending on size and network conditions

---

## CI/CD Compatibility
* Designed for headless execution
* Works with GitHub Actions, Jenkins, Azure DevOps
* No manual setup required

---

## Roadmap

Planned enhancements:
* Parallel execution (Pabot integration)
* Resume capability for long scans
* Cross-platform support improvements
* Advanced analytics (top objects, trends)

---


## Troubleshooting

| Issue                     | Cause                             | Fix                                          |
|---------------------------|-----------------------------------|----------------------------------------------|
| sf not found              | CLI not installed                 | Install Salesforce CLI                       |
| Org alias not found       | Not authenticated                 | sf org login web                             |
| JSON parse error          | CLI warnings                      | Safe Parse handles most cases                |
| No results / empty output | Auth expired or permissions issue | Re-run sf org login web or check permissions |

---

## Security

* No credentials stored in code
* Uses Salesforce CLI authentication
* Sensitive files should be excluded via .gitignore

---

## Contributing

**Contributions are welcome!**

* Open issues for bugs
* Submit pull requests for improvements
* Follow existing coding patterns
* Performance improvements 
* Better error classification 
* Additional output formats 
* Feature enhancements

## Support

If this project helps you:

- Star ⭐ the repository  
- Share feedback  
- Open issues for improvements  

Your support helps improve and maintain the project.
---

## Author
 
**Bhimeswara Vamsi Punnam** — Lead Software Development Engineer in Test (SDET)
 
**Contact:** [![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/bvamsipunnam)

---

## License

This project is licensed under the MIT License.  
See the [LICENSE](LICENSE) file for full terms and conditions.