# Authentication

The scanner uses a Salesforce CLI org alias. It does not have a separate login
flow and does not ask for a username, password, or token.

## Log in

Authenticate interactively and assign an alias:

```bash
sf org login web --alias MyOrg
```

Confirm the alias before starting a scan:

```bash
sf org display --target-org MyOrg
```

Pass the same alias to Robot Framework:

```bash
robot -d results --variable ORG_ALIAS:MyOrg src/robot/orchestrator/scan.robot
```

## Use the right Salesforce user

The report only covers objects that the authenticated user can discover and
query. Use the least access needed for the job, but make sure the account can see
the objects that matter to the review. Test code changes against a non-production
org.

## Expired or invalid sessions

If `sf org display --target-org MyOrg` fails, authenticate again before running
the scanner. The scanner checks the alias at startup, but it does not manage the
CLI session for you.

---

[Back to README](../README.md) | [Installation](installation.md) | [Configuration](configuration.md)
