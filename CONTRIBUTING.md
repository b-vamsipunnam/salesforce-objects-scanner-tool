# Contributing

Small, focused changes are easiest to review. If you are planning a new feature
or a change to report behavior, open an issue first so the approach can be
discussed before you spend time implementing it.

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Security problems belong
in a private report; see [SECURITY.md](SECURITY.md).

## Local setup

```bash
git clone https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool.git
cd salesforce-objects-scanner-tool
python -m venv venv
python -m pip install -r requirements-dev.txt
```

Python 3.10 or later is required. Salesforce CLI is only needed for a live scan;
the regular test suite uses a fake CLI.

## Checks to run

Run the following before opening a pull request:

```bash
python -m unittest discover -s tests -v
robot -d results-smoke ci/robot/smoke.robot
robot -d results-parallel ci/robot/parallel_smoke.robot
robot --dryrun -d results-dryrun src/robot/orchestrator/scan.robot
ruff check src tests ci/fakes
robocop check src/robot ci/robot
```

Use a non-production org for changes that need a real Salesforce check:

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

Review `Skipped Objects` before describing a live scan as successful. Remove org
names, URLs, tokens, and customer data from anything attached to an issue or pull
request.

## Project conventions

- Keep the command-line entry point in `src/robot/orchestrator/`.
- Put reusable Robot behavior in `src/robot/resources/`.
- Use the Python libraries for parsing, platform integration, and workbook work
  that is clearer outside Robot Framework.
- Do not hard-code org aliases, credentials, output paths, or object lists.
- Keep each run isolated and preserve the temporary-file-to-final-file artifact
  write pattern.
- Add a narrow test before adding or changing an expected Salesforce error rule.
- Update the relevant guide when a command, variable, output file, or failure
  rule changes.

## Pull requests

A pull request should explain the problem, the chosen fix, and the checks you
ran. Link the related issue when there is one. Keep unrelated cleanup in a
separate change.

Commit subjects should be short and imperative, for example:

```text
Fix transient query classification
Document Tooling discovery failures
```

## Live validation in GitHub Actions

Maintainers can run the `Live Salesforce Validation` workflow against an
approved non-production org.

1. Create a GitHub Environment named `salesforce-live-validation`.
2. Store the org's SFDX auth URL in an environment secret named `SF_AUTH_URL`.
3. Add the required reviewers or other environment protection rules.
4. Run **Actions → Live Salesforce Validation** and confirm that the org is not
   production.

The workflow uses the alias `live-validation`, runs a small Pabot-backed scan,
deletes its temporary auth file, and uploads the Robot results. Never put the
auth URL in a workflow input, repository file, log, issue, or pull request.

## Reporting a bug

Search the open issues first. If the problem is new, include the Python,
Salesforce CLI, and operating-system versions; the command you ran; the expected
behavior; and sanitized Robot output. A small reproducible case is more useful
than a full production log.
