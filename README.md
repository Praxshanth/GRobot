<div align="center">

# GRobot

**The self-hosted AI operating layer for businesses.**

AI agents that handle conversations, leads and workflows, with humans approving what matters.

![License: Proprietary](https://img.shields.io/badge/license-proprietary-red)

</div>

> **Proprietary software.** This repository is confidential and is not open source. No one may
> use, copy or fork it without a signed enterprise agreement. See [LICENSE](LICENSE).

## What this repository is

GRobot-D is a copy of GRobot with **HashiCorp Vault, the SecretProvider port, the Pieces integration
layer (Piece Host, catalogue, executors, triggers) and OAuth connections removed**. Connections
can only be `auth_type: none`; there is no stored per-connection or per-workspace credential.
Organization-level AI provider keys still use the AES-GCM store (`GROBOT_SECRET_MASTER_KEY`).
Database migrations are kept as-is, so the removed features' tables still exist but are unused.

## Overview

GRobot gives a business a team of AI agents that read the inbox, answer customers, qualify
leads and act in the tools it already uses. It is multi-tenant, runs on your own infrastructure,
and keeps people in the loop. The first vertical is construction and home services.
More in [ABOUT.md](ABOUT.md).

## Capabilities

| Area | What it does |
|---|---|
| **Agents and Cortex** | Unified agents on a native runtime, acting under bounded service accounts |
| **Inbox, Approvals, Leads** | Conversations, human approval of risky actions, lead tracking |
| **Knowledge and Workflows** | Retrieval over your documents; outline-first workflow builder |
| **Connect** | REST, webhook and MCP connections, with no stored credentials |
| **GRobot MCP** | MCP server with OAuth, plus a governed Tool Registry with risk categories |
| **Governance** | Audit trail, usage, MCP review, role-based access, SSO (OIDC and SAML) |
| **Observe** | Activity and analytics |

## Architecture

Monorepo: `apps/web` (Next.js), `apps/api` (FastAPI), `packages/core` (domain and services),
`services/mcp`, backed by PostgreSQL (pgvector), Redis, MinIO and
Celery workers. Details: [docs/architecture.md](docs/architecture.md), decisions in
[docs/adr](docs/adr), plan in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

## Quick start
```bash
make setup      # deps + .env
make up         # postgres(pgvector), redis, minio, mailpit
make up-sso     # optional: also start Authentik as a test OIDC identity provider
make api        # http://localhost:8000/health · /api/v1/docs
make mcp        # GRobot MCP service (MCP endpoint + OAuth server) on :8020 · docs/mcp.md
make web        # http://localhost:3000
make check      # format, lint, typecheck, tests
make e2e        # end-to-end tests (API + real browser) against the real stack
make seed       # labeled demo data;  make reset-db  # start over
```
Local services: MinIO console :9001, Mailpit :8025. With `make up-sso`: Authentik http://localhost:9002 (test users `owner@summitridge.test` / `grobot-dev-password`).
Auth: built-in email/password plus any OIDC provider (see ADR 0004); no external IdP is required.
`infrastructure/docker/compose.yml` is development-only. Production (Dokploy): [docs/deploy-dokploy.md](docs/deploy-dokploy.md) with `compose.prod.yml`; architecture notes in [docs/deployment.md](docs/deployment.md).

## Documentation

[Development](docs/development.md) · [Deployment](docs/deployment.md) ·
[Dokploy](docs/deploy-dokploy.md) · [MCP](docs/mcp.md) · [Connect](docs/connect.md) ·
[Governance](docs/govern.md)

## Security

Report vulnerabilities privately, never in a public issue: see [SECURITY.md](SECURITY.md).

## License

Copyright (c) 2026 GRTechAdvisory. All rights reserved. Proprietary; see [LICENSE](LICENSE).
Third-party components keep their own licences: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
