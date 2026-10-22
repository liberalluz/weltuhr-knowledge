# Security Policy

## Supported versions

Security updates are provided for the following versions only:

| Version | Supported |
|---|---|
| The latest released minor version | ✅ |
| Earlier minor versions / all patch-only branches | ❌ |

> Rule: **latest minor only**. Users on older versions must upgrade to the latest minor to receive security fixes.

## Reporting a vulnerability

**Please do not report security vulnerabilities through public issues.**

Submit them via this repository's **Security** page → **Report a vulnerability** (GitHub's private vulnerability reporting channel).
That channel is visible to maintainers and invisible to the public, which allows private collaboration until a fix is released.

Please include as much of the following as you can: affected version, reproduction steps, your assessment of the impact, and a minimal reproduction sample where possible.

## Response time

We aim to reply for the first time within **7 business days** of receiving a report.

> ⚠️ This policy **does not constitute an SLA**. The time limit and the channel are both external commitments; any change requires change control and an explicit announcement in this file.

## Out of scope

The following are outside the scope of this policy; please use the regular issue tracker:

- vulnerabilities in upstream projects we depend on (please report them upstream as well)
- attacks that require physical access to the device, or that are only reachable after gaining administrative access to it
- correctness problems in the knowledge content of a content pack (`content/`) — use a content erratum issue
- pure configuration advice, hardening suggestions, and scanner warnings that come without a reproduction path
