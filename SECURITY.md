# Security Policy

GRobot handles customer credentials, business data and AI-driven actions, so we treat security
reports as the highest priority.

## Reporting a vulnerability

**Do not open a public issue.** Report privately through GitHub:
**Security → Report a vulnerability** on this repository (private vulnerability reporting).
If you have an Enterprise Agreement, you may also use the security contact it names.

Please include what you found, the affected component and version or commit, steps to
reproduce, and the impact you expect. Never include real customer data or secrets.

## What to expect

| Step | Target |
|---|---|
| Acknowledgement | within 2 business days |
| Initial assessment and severity | within 5 business days |
| Fix or mitigation plan for High/Critical | within 14 days |
| Disclosure | coordinated with you after a fix ships |

## Scope

In scope: the API, web app, MCP service, Cortex runtime, authentication and
authorisation, multi-tenant isolation, the
approval and governance controls, and the deployment configuration in this repository.

Out of scope: social engineering, denial-of-service and volumetric testing, physical
attacks, findings in third-party software with no GRobot-specific impact (report those
upstream), and any testing against systems or data you are not authorised to test.

## Safe harbour

Good-faith research that stays within this policy, avoids privacy violations and service
disruption, and gives us reasonable time to respond will not be pursued by GRTechAdvisory.

## Supported versions

Only the latest `develop` release is supported with security fixes.

## Handling secrets

Secrets are never committed. If you find one in this repository or its history, report it
as a vulnerability so it can be rotated.
