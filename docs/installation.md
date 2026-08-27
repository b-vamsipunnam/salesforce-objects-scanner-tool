# Installation

This page sets up the scanner on your computer. Salesforce sign-in is covered
separately in [Authentication](authentication.md).

## 1. Install the prerequisites

You need:

- [Git](https://git-scm.com/downloads) to clone the repository
- [Python](https://www.python.org/downloads/) 3.10 or later
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)

Salesforce CLI is the `sf` command-line program that the scanner uses to contact
Salesforce. Node.js is needed only if you choose Salesforce's npm installation
method.

Open the terminal you plan to use for the scanner and check each command:

```bash
git --version
python --version
sf --version
```

Each command should print a version. If `sf` is not found, finish the Salesforce
CLI installation and open a new terminal. See [Troubleshooting](troubleshooting.md)
for PowerShell and `PATH` problems.

## 2. Download the project

```bash
git clone https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool.git
cd salesforce-objects-scanner-tool
```

You should now be in the directory that contains `README.md` and
`requirements.txt`.

## 3. Create a virtual environment

A virtual environment keeps this project's packages separate from the rest of
your Python installation.

```bash
python -m venv venv
```

Activate it on Windows PowerShell:

```powershell
.\venv\Scripts\Activate.ps1
```

Or activate it on Windows Command Prompt:

```bat
venv\Scripts\activate.bat
```

Activate it on macOS or Linux:

```bash
source venv/bin/activate
```

The terminal prompt usually starts with `(venv)` after activation. Keep this
environment active when you install or run the scanner.

## 4. Install the scanner

```bash
python -m pip install -r requirements.txt
```

Confirm that Robot Framework is available:

```bash
robot --version
```

The command should print a Robot Framework version. Installation is now
complete.

Next: [sign in to Salesforce](authentication.md). To work on the project itself,
see [Contributing](../CONTRIBUTING.md).
