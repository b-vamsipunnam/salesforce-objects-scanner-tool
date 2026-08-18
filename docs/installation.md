# Installation

Before starting, make sure the following are installed:

- Python 3.10 or newer
- Salesforce CLI (`sf`)
- Access to a Salesforce org
- Node.js only when installing Salesforce CLI through npm

Check Python and Salesforce CLI from the same terminal you will use for the
scan:

```bash
python --version
sf --version
```

## Create the environment

```bash
git clone https://github.com/b-vamsipunnam/salesforce-objects-scanner-tool.git
cd salesforce-objects-scanner-tool
python -m venv venv
```

Activate the environment on Windows:

```powershell
venv\Scripts\Activate.ps1
```

Activate it on macOS or Linux:

```bash
source venv/bin/activate
```

Install runtime dependencies:

```bash
python -m pip install -r requirements.txt
```

If you plan to run the tests or linters, install the development requirements:

```bash
python -m pip install -r requirements-dev.txt
```

---

[Back to README](../README.md) | [Authentication](authentication.md)
