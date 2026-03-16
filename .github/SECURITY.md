# Security Policy

## Scope

This project is a status line renderer for Claude Code. It processes JSON from Claude Code via stdin and outputs ANSI text. It does not handle authentication, network requests, or user credentials.

The main security-relevant area is **cache.sh**, which writes to a per-user temp directory. Branch names are sanitized via single-quote escaping to prevent shell injection when the cache file is sourced.

## Reporting a Vulnerability

If you find a security issue (especially anything related to shell injection via crafted JSON input or branch names), please report it privately:

1. Go to the [Security Advisories](https://github.com/gfreschi/claude-code-statusline/security/advisories) page
2. Click "Report a vulnerability"
3. Describe the issue and how to reproduce it

I'll respond within 72 hours and work on a fix before any public disclosure.

Please do not open a public issue for security vulnerabilities.

## Supported Versions

Only the latest version on `main` is supported.
