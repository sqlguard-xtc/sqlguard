# Security Policy

## Supported Versions

Security updates will be provided for the latest major version.

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in SqlGuard, please report it by emailing:

**Email:** security@sqlguard.dev

Please include:
- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes (if available)

We will acknowledge your report within 48 hours and provide a detailed response within 5 business days indicating the next steps.

## Security Best Practices

When using SqlGuard:
- Use environment variables for connection strings (never hardcode credentials)
- Limit database permissions to minimum required for validation
- Run SqlGuard with least-privilege service accounts in CI/CD
- Review validation logs for sensitive data before publishing
- Keep SqlGuard updated to the latest version
