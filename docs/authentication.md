# Authentication

The scanner uses a login saved by Salesforce CLI. It does not ask for a
Salesforce username, password, or token, and it does not store those credentials
in this repository.

## Orgs and aliases

A Salesforce org is a Salesforce environment, such as a production org,
sandbox, or scratch org. An org alias is a short name that Salesforce CLI saves
on your computer for one authenticated org. The examples use `MyOrg`; you can
choose another alias.

## Required access

The Salesforce user must have:

- Access to an org edition with Salesforce API access
- The Salesforce **API Enabled** user permission
- Visibility and read access for the objects and records that should be counted
- Access to Tooling API objects if those optional setup and development objects
  are in scope

There is no single project-specific permission set. Salesforce features,
licenses, object permissions, and record sharing all affect what one user can
discover and count. Use an account with enough access for the purpose of the
scan, but do not grant unrelated permissions merely to remove skipped rows. The
scanner only sends discovery and read queries; it does not modify Salesforce
data.

Salesforce documents the
[API Enabled permission](https://help.salesforce.com/s/articleView?id=platform.admin_userperms.htm&type=5)
and [editions with API access](https://help.salesforce.com/s/articleView?id=000005140&type=1).

## Log in with Salesforce CLI

Run:

```bash
sf org login web --alias MyOrg
```

The command opens Salesforce in your default browser. Complete the sign-in and
close the browser when Salesforce confirms the login. Salesforce CLI then saves
the connection under the `MyOrg` alias.

If your org uses a sandbox or custom login URL, follow the Salesforce CLI
[`org login web` reference](https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference_org_login_web.html)
for the appropriate `--instance-url` value.

## Check the alias

```bash
sf org display --target-org MyOrg
```

The command should show the selected org without an authentication error. Its
output includes sensitive connection information, so do not save or share it.
Keep using the same alias when you run the scanner.

Next: [run a scan](usage.md). If the alias is rejected later, see
[Troubleshooting](troubleshooting.md#the-org-alias-is-rejected).
