# Contributing to Salesforce Objects Scanner Tool

Thank you for your interest in contributing!  
We welcome bug reports, feature requests, documentation improvements, and code contributions.

---

## Getting Started

### 1. Fork & Clone

```bash
git clone https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool.git
cd salesforce-objects-scanner-tool
```

---

### 2. Set Up the Environment

Make sure you have the following installed:

* Python 3.10+
* Node.js (18+)
* Robot Framework
* Salesforce CLI

Install dependencies:

```bash
pip install -r requirements-dev.txt
```

Configure Salesforce org authentication:

```bash
sf org login web
```

---

## Running Tests

Before submitting changes, ensure all tests pass:

```bash
python -m unittest discover -s tests -v
robot -d results-smoke ci/robot/smoke.robot
robot -d results-parallel ci/robot/parallel_smoke.robot
robot --dryrun -d results-dryrun src/robot/orchestrator/scan.robot
ruff check src tests ci/fakes
robocop check src/robot ci/robot
```

These checks do not need a Salesforce org. Run a live scan separately when the
change affects Salesforce behavior:

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

### Optional live Salesforce validation workflow

Normal CI does not use Salesforce credentials. Maintainers can manually run the
`Live Salesforce Validation` GitHub Actions workflow against an approved
non-production org.

1. Create a GitHub Environment named `salesforce-live-validation`.
2. Add an environment secret named `SF_AUTH_URL` containing an SFDX auth URL for
   a sandbox, scratch org, or other approved non-production org.
3. Add appropriate environment protection rules or required reviewers.
4. Open **Actions → Live Salesforce Validation → Run workflow**.

The workflow fails before authentication when the secret is missing. Never put
the auth URL in repository files, workflow inputs, logs, issues, or pull
requests. The workflow authenticates with the alias `live-validation`, runs a
one-object Pabot-backed validation, and uploads the Robot results as workflow
artifacts.

---
## Development Workflow

1. Create a feature branch
2. Implement changes
3. Run tests locally
4. Update documentation
5. Submit pull request

---

## How to Contribute

### Reporting Bugs

If you find a bug:

1. Check existing issues first
2. Create a new issue with:

   * Clear description
   * Steps to reproduce
   * Logs/screenshots
   * Environment details

---

### Suggesting Enhancements

We welcome feature ideas! Open an issue with:

* Problem statement
* Proposed solution
* Use cases

---

## Submitting Code Changes

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

Examples:

* `feature/download-timeout`
* `feature/batch-retry`
* `feature/update-readme`

---

### 2. Make Your Changes

* Follow existing coding patterns
* Keep commits focused
* Add comments where needed
* Update documentation if required

---

### 3. Commit Guidelines

Use meaningful commit messages:

```bash
git commit -m "Fix: Handle invalid object query"
```

Format:

```
Type: Short description

Examples:
Fix: ...
Feat: ...
Docs: ...
Refactor: ...
```

---

### 4. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then open a Pull Request on GitHub.

Your PR should include:

* Description of changes
* Related issue number (if any)
* Testing details

---

## Code Style Guidelines

### Robot Framework

* Use descriptive keyword names
* Keep keywords reusable
* Avoid hardcoded paths
* Use variables wherever possible

Example:

```robot
Get Object Record Count
    [Arguments]    ${object_name}
    Log    Processing ${object_name}
```
---

## Security

Never commit:

* Access tokens
* Passwords
* secrets

Guidelines:

* Use `.gitignore` for sensitive files
* Report vulnerabilities privately

---

## Documentation

If your change impacts usage:

* Update `README.md`
* Add examples
* Update comments

Good documentation is highly valued!

See also:
* README.md
* docs/architecture.md
* SECURITY.md

---

## Community Guidelines

Please be respectful and constructive.

We follow these principles:

* Be professional
* Be inclusive
* Be helpful
* Accept feedback gracefully

---
## Review Process

* All pull requests are reviewed by the maintainer
* Feedback may be requested
* Changes must pass CI before merge

---

## Contact

For major changes or discussions, please open an issue first.

Maintainer: **Bhimeswara Vamsi Punnam**

---

###   Thank you for contributing!

---
