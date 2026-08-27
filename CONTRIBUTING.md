# Contributing

Keep changes focused. Open an issue before starting a new feature or changing
report behavior so maintainers can agree on the approach.

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems
privately as described in [SECURITY.md](SECURITY.md).

## Set up a development environment

Python 3.10 or later is required. Follow the
[download](docs/installation.md#2-download-the-project) and
[virtual-environment](docs/installation.md#3-create-a-virtual-environment)
steps in the installation guide. Then install the development requirements from
the repository root:

```bash
python -m pip install -r requirements-dev.txt
```

This file includes the runtime packages, Ruff, and Robocop. Salesforce CLI is
needed only for a live-org check; the automated smoke tests use a fake CLI.

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

These checks do not require a Salesforce login. If a change needs a manual live
check, follow [Authentication](docs/authentication.md) and
[Usage](docs/usage.md) with an approved non-production org. Review the
`Skipped Objects` sheet and remove org names, URLs, tokens, counts, and customer
data from anything attached to an issue or pull request.

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

## Maintainer live validation

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

Search open issues first. For a new problem, include the Python, Salesforce CLI,
and operating-system versions, the command you ran, the expected result, and
sanitized Robot output. Prefer a small reproducible example to a production log.
