# Security Policy

Keyholdr stores API keys and other secrets in the macOS Keychain / Windows
Credential Locker, gated behind Touch ID, Apple Watch, or Windows Hello.
Security issues are taken seriously — please report them privately.

## Reporting a vulnerability

**Do not open a public issue for security vulnerabilities.**

Instead, email **ashwini.sharma0807@gmail.com** with:

- A description of the issue and its potential impact
- Steps to reproduce (proof-of-concept code or commands, if applicable)
- The Keyholdr version and platform (macOS/Windows) affected

You should receive a response within a few days. Once a fix is available,
the report will be credited in the release notes (unless you'd prefer to
remain anonymous).

## Supported versions

Only the latest released version is supported with security fixes.

## Scope

In scope:
- Keyholdr macOS app, CLI, and Windows app
- The vault export/import format (PBKDF2 + AES-GCM)
- Keychain / Credential Locker access-control configuration

Out of scope:
- The [marketing site](https://github.com/OlixIgnacious/keyholdr-site)
  (report via that repo's issues instead, unless it's a vulnerability in the
  site infrastructure itself)
- Third-party dependencies (report upstream, but feel free to let us know too)
