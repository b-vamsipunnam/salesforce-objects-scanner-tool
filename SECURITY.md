# Security Policy

## Reporting Security Vulnerabilities

We take the security of this project seriously and appreciate responsible disclosure.

If you discover a security vulnerability, please report it privately so it can be addressed promptly.

### Please do NOT:
- Open a public GitHub issue
- Share details publicly (e.g., social media, forums)
- Exploit the vulnerability

---

## How to Report

Please contact the maintainer directly:

**Maintainer:** Bhimeswara Vamsi Punnam  
**Preferred Method:** GitHub private message or repository contact  

If private messaging is unavailable, open a minimal issue requesting a secure communication channel.

We aim to acknowledge reports within **72 hours** and provide updates during the investigation.

### Include the following details:
- Description of the vulnerability  
- Steps to reproduce  
- Proof of concept (if available)  
- Impact assessment  
- Affected versions  
- Suggested fixes (if any)  

---

## Security Best Practices

### Credentials & Secrets
- Never commit sensitive data such as:
  - Access tokens  
  - OAuth secrets  
  - Passwords  
- Use environment variables or secure vaults  
- Ensure sensitive files are included in `.gitignore`

---

### Salesforce Access
- Follow the principle of least privilege  
- Avoid using production admin credentials  
- Rotate tokens regularly  
- Log out of unused sessions  

---

### Dependencies
- Keep dependencies up to date  
- Monitor for known vulnerabilities  
- Use trusted and maintained packages  

---

### Local Environment
- Secure your local machine  
- Avoid running the tool on shared or public systems  
- Encrypt sensitive files when needed  
- Restrict access to configuration files  

---

## Disclosure Process

We follow a responsible disclosure approach:

1. Report received privately  
2. Vulnerability verified  
3. Fix developed and tested  
4. Patch released  
5. Public disclosure (if appropriate)  

Contributors who report issues responsibly may be credited (with permission).

---

## Security Updates

Security updates and advisories will be shared via:
- GitHub Releases  
- Repository changelog  
- Project documentation  

For critical issues, CVE identifiers may be requested when appropriate.

---

## Disclaimer

This project is provided “as is” without warranty.  
Users are responsible for securing their environments, credentials, and data.

---

Thank you for helping keep this project secure.