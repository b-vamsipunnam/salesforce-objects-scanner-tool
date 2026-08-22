# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Use **Security → Report a vulnerability** when private vulnerability reporting
is available for this repository. Otherwise, contact the maintainer privately
through the contact details on their GitHub profile. If neither option is
available, open an issue that asks for a private contact channel without
describing the vulnerability.

A useful private report includes:

- What is affected and why it matters
- The version or commit you tested
- The smallest set of steps needed to reproduce the problem
- A suggested fix or mitigation, if you have one

Remove Salesforce credentials, customer data, org URLs, and unrelated log
content. Do not access data that is not yours or publish details before a fix is
available.

## Credentials and scan output

The scanner uses Salesforce CLI authentication. Credentials should never be
stored in the repository or passed as Robot variables.

- Do not commit access tokens, SFDX auth URLs, session IDs, passwords, or OAuth
  secrets.
- Keep `.sf/`, `.sfdx/`, auth files, Robot reports, and `output/` out of Git.
- Use a non-production org for development and live validation.
- Limit access to generated workbooks, JSON files, and logs. They can reveal
  object names, record counts, and Salesforce error details.
- Rotate or revoke credentials if they may have been exposed.

The scanner redacts recognized tokens, authorization headers, and authentication
URLs from Salesforce errors. That is a safeguard, not a reason to treat output
as public data.

The live GitHub Actions workflow reads `SF_AUTH_URL` from the protected
`salesforce-live-validation` environment, writes it to a restricted temporary
file, and removes the file after login. The secret must point to an approved
non-production org.

## Supported code

Security fixes are made on the current `main` branch. This project does not
maintain older release branches.

This project is provided under the [MIT License](LICENSE). Operators remain
responsible for their Salesforce access, local environment, and generated
files.
