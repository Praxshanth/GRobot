COMPOSE = docker compose -f infrastructure/docker/compose.yml --env-file .env

.PHONY: platform-inventory platform-keys platform-dev platform-api platform-web platform-admin platform-test billing-test gateway-test router-test router-eval prod-check prod-compose-check release-candidate e2e-preflight verify-patches e2e-rc  reset-db seed rotate-secrets resync-sso e2e setup up up-sso up-app down web-build dev dev-stop logs fmt lint typecheck test check api web worker migrate migration mcp mcp-test key-gateway approvals-test registry-test cortex-test agent-actions-test start

setup:  ## install deps and create .env
	@test -f .env || (cp .env.example .env && python3 infrastructure/scripts/gen_dev_secrets.py .env)
	uv sync --all-packages
	pnpm install

up:  ## start infrastructure (postgres, redis, minio, mailpit)
	$(COMPOSE) up -d

up-sso:  ## infrastructure plus Authentik as a test OIDC identity provider
	$(COMPOSE) --profile sso up -d

up-app:  ## start infrastructure plus containerised api/worker/web
	$(COMPOSE) --profile app up -d --build

down:
	$(COMPOSE) --profile app --profile sso down

web-build:  ## build the web app for `make dev`, sized for a small machine; run it with nothing else running
	GROBOT_NEXT_LOW_MEMORY=1 NEXT_TELEMETRY_DISABLED=1 NODE_OPTIONS=--max-old-space-size=2048 pnpm --filter @grobot/web build

dev: up  ## start infrastructure plus every service (and the Connector Hub if it sits next to this repo) in the background (logs in .dev-logs/); needs `make web-build`
	@bash infrastructure/scripts/dev_all.sh start

start:  ## one command: setup, build the web app if missing, then start everything (`make dev-stop` to stop)
	@$(MAKE) setup
	@test -f apps/web/.next/BUILD_ID || $(MAKE) web-build
	@$(MAKE) dev

dev-stop:  ## stop the services `make dev` started (the containers keep running; `make down` stops them)
	@bash infrastructure/scripts/dev_all.sh stop

logs:
	$(COMPOSE) logs -f --tail=100

api:  ## run the public API (:8000) and the internal API (:8001) with reload
	@trap 'kill 0' INT TERM EXIT; \
	uv run uvicorn grobot_api.internal_main:app --reload --port 8001 & \
	uv run uvicorn grobot_api.main:app --reload --port 8000 & \
	wait

reset-db:  ## DROP and rebuild the local development database (all data lost)
	uv run python infrastructure/scripts/reset_dev_db.py

seed:  ## create labeled DEMO data (needs `make up api web` running)
	uv run python infrastructure/scripts/seed_demo.py

rotate-secrets:  ## re-encrypt stored secrets under the current keys, then re-sync SSO (see script docstring)
	uv run python infrastructure/scripts/rotate_secrets.py

resync-sso:  ## re-push all active SSO connections to the auth service (after key rotation)
	uv run python infrastructure/scripts/resync_sso.py

worker:  ## run the background worker (+ scheduler). Threads pool: Celery's prefork pool breaks on macOS
	uv run celery -A grobot_worker.app:celery_app worker -B -P threads -c 4 -Q default,ingest,events,flow,cortex -l info

mcp:  ## run the GRobot MCP service (public MCP endpoint + OAuth server) on :8020
	uv run uvicorn grobot_mcp.main:app --port 8020 --reload

web:  ## run the web app on GROBOT_WEB_PORT from .env (default 3000)
	PORT=$$(sed -n 's/^GROBOT_WEB_PORT=//p' .env | grep . || echo 3000) pnpm --filter @grobot/web dev

approvals-test:  ## the M13.1 checks: approval engine, gateway, flow, MCP, API, security and concurrency (no containers)
	uv run pytest -q -m "not docker" packages/core/tests/test_approvals_primitives.py packages/core/tests/test_import_boundaries.py packages/core/tests/db/test_action_approvals.py packages/core/tests/db/test_action_approvals_flow.py packages/core/tests/db/test_tool_gateway.py packages/core/tests/db/test_flow_runner.py packages/core/tests/db/test_security_definer_standard.py apps/api/tests/test_action_approvals.py apps/api/tests/test_approvals.py services/mcp/tests/test_mcp_approvals.py

registry-test:  ## the M13.2 checks: registry, risk governance, search, scheduled MCP rediscovery, OAuth cleanup, boundaries (no containers)
	uv run pytest -q -m "not docker" packages/core/tests/test_toolregistry_primitives.py packages/core/tests/test_import_boundaries.py packages/core/tests/db/test_tool_registry.py packages/core/tests/db/test_tool_risk_governance.py packages/core/tests/db/test_mcp_rediscovery.py packages/core/tests/db/test_security_definer_standard.py packages/core/tests/db/test_tool_gateway.py apps/api/tests/test_tool_registry.py services/mcp/tests/test_mcp_registry_search.py

cortex-test:  ## the M13.3 checks: runtime, durability, crash recovery, safety, persistence, Flow AGENT node, model adapters, API, boundaries
	uv run pytest -q -m "not docker" packages/core/tests/test_cortex_primitives.py packages/core/tests/test_import_boundaries.py packages/core/tests/db/test_cortex_runtime.py packages/core/tests/db/test_cortex_durability.py packages/core/tests/db/test_cortex_crash.py packages/core/tests/db/test_cortex_safety.py packages/core/tests/db/test_cortex_persistence.py packages/core/tests/db/test_cortex_flow.py packages/core/tests/db/test_security_definer_standard.py services/ai-runtime/tests/test_cortex_models.py apps/api/tests/test_cortex.py

agent-actions-test:  ## the M13.4 checks: conversation -> Cortex (identity, allowlist, approvals, idempotency, safe results, revocation, tenants), chat-runtime triggers, API, Agent/Cortex/Flow regression (no containers)
	uv run pytest -q -m "not docker" packages/core/tests/test_agent_actions_primitives.py packages/core/tests/test_import_boundaries.py packages/core/tests/db/test_agent_actions.py packages/core/tests/db/test_cortex_flow.py packages/core/tests/db/test_security_definer_standard.py services/ai-runtime/tests/test_actions.py services/ai-runtime/tests/test_runtime.py services/ai-runtime/tests/test_lead_runtime.py apps/api/tests/test_agent_actions.py apps/api/tests/test_agent_cortex_link.py apps/api/tests/test_action_approvals.py apps/api/tests/test_public_api.py apps/api/tests/test_handoff.py apps/api/tests/test_leads.py

computer-runtime-env:  ## the browser runtime's own virtualenv (Browser Use lives only here; the application pins an incompatible mcp)
	cd services/computer-runtime && uv venv --python 3.12 .venv && uv pip install --python .venv/bin/python -e . "browser-use==0.13.11" pytest pytest-asyncio httpx && uv pip install --python .venv/bin/python --no-deps -e ../../packages/core

computer-agent-test:  ## the Browser Use driver's tests (run in the runtime's own virtualenv; `make computer-runtime-env` first)
	cd services/computer-runtime && .venv/bin/python -m pytest tests -q

migrate:  ## apply database migrations (owner role): platform schema, then Better Auth schema
	uv run alembic upgrade head
	set -a; . ./.env; set +a; cd apps/web && AUTH_DATABASE_URL=$$(echo $$GROBOT_DATABASE_ADMIN_URL | sed 's/+psycopg//') \
		pnpm exec better-auth migrate --config auth.config.ts -y

migration:  ## autogenerate: make migration m="message"
	uv run alembic revision --autogenerate -m "$(m)"

platform-api:  ## the platform console's own API (GROBOT_API_ROLE=platform) on :8100, for the admin host (ADR 0073, docs/admin-host.md)
	GROBOT_API_ROLE=platform GROBOT_AUTH_AUDIENCE=grobot-platform GROBOT_PLATFORM_URL=http://admin.localhost:3100 \
	GROBOT_AUTH_JWKS_URL=http://localhost:3100/api/auth/jwks GROBOT_CORS_ALLOWED_ORIGINS='["http://admin.localhost:3100"]' \
	GROBOT_SERVICE_NAME=grobot-api-platform uv run uvicorn grobot_api.main:app --reload --port 8100

platform-web:  ## the admin web deployment (GROBOT_WEB_ROLE=admin) on http://admin.localhost:3100: the console at its root
	cp apps/web/tsconfig.json apps/web/tsconfig.alt-admin.json
	cd apps/web && GROBOT_WEB_ROLE=admin BETTER_AUTH_URL=http://admin.localhost:3100 GROBOT_AUTH_ISSUER=$${GROBOT_AUTH_ISSUER:-http://localhost:3000} \
	GROBOT_AUTH_AUDIENCE=grobot-platform GROBOT_API_URL=http://localhost:8100 GROBOT_NEXT_DIST_DIR=.next-admin \
	GROBOT_NEXT_TSCONFIG=tsconfig.alt-admin.json pnpm exec next dev -p 3100

platform-keys:  ## generate the admin console's signing key pair + auth secret (prints variables; store in the secret store, never git)
	uv run python infrastructure/scripts/platform_keys.py generate

platform-dev:  ## the console on its own host locally: run `make api web` as usual, then `make platform-api` and `make platform-web` (two terminals); open http://admin.localhost:3100
	@echo "Run in separate terminals:  make platform-api   and   make platform-web"
	@echo "Then open http://admin.localhost:3100 (sign in; staff need an authenticator app, see docs/admin-host.md)"

platform-admin:  ## platform staff, owner connection: make platform-admin ARGS="grant --email you@grobot.example --ticket OPS-1 --reason '...'" (also: list, revoke, set-setting, verify-audit, anchor, verify-export)
	uv run python infrastructure/scripts/platform_admin.py $(ARGS)

platform-inventory:  ## regenerate docs/platform-admin-action-inventory.md from the platform routers
	uv run python -m grobot_api.platform_inventory > docs/platform-admin-action-inventory.md

platform-test:  ## the P-12.1 checks: pure rules, database (isolation, ledger, anchor, recovery, concurrency), migration rehearsal, model-boundary suspension, API, web helpers
	uv run pytest -q packages/core/tests/test_platform_primitives.py packages/core/tests/test_config.py packages/core/tests/db/test_platform_control_plane.py packages/core/tests/db/test_platform_isolation.py packages/core/tests/db/test_platform_ledger.py packages/core/tests/db/test_platform_audit_anchor.py packages/core/tests/db/test_platform_recovery.py packages/core/tests/db/test_platform_concurrency.py packages/core/tests/db/test_platform_migration.py packages/core/tests/db/test_platform_standing.py packages/core/tests/db/test_tenancy_guards.py packages/core/tests/db/test_security_definer_standard.py services/ai-runtime/tests/test_suspension_at_model_boundary.py apps/api/tests/test_platform_api.py apps/api/tests/test_platform_security.py apps/api/tests/test_platform_inventory.py
	pnpm --filter @grobot/web exec vitest run src/lib/platform.test.ts src/lib/table-state.test.ts src/lib/platform-client.test.ts src/lib/sign-in-claims.test.ts src/lib/two-factor-copy.test.ts

billing-test:  ## P-12.5 SaaS billing: primitives, rating, wallet, payments, lifecycle, admin, sweeper, effects, performance, API, web helpers (Stripe is contract-tested only; no payment is made)
	uv run pytest -q packages/core/tests/test_billing_primitives.py packages/core/tests/test_billing_payments.py packages/core/tests/db/test_billing_rating.py packages/core/tests/db/test_billing_payments.py packages/core/tests/db/test_billing_lifecycle.py packages/core/tests/db/test_billing_admin.py packages/core/tests/db/test_billing_sweeper.py packages/core/tests/db/test_billing_effects.py packages/core/tests/db/test_billing_performance.py apps/api/tests/test_billing_api.py
	pnpm --filter @grobot/web exec vitest run src/lib/billing.test.ts src/lib/platform.test.ts

gateway-test:  ## P-12.2 + completion: gateway, providers (contract), proxy, health, attribution, policy, router seam, migration, platform API, web helpers (live provider tests skip without GROBOT_LIVE_OPENROUTER_KEY)
	uv run pytest -q -m "not docker" packages/core/tests/test_gateway_primitives.py packages/core/tests/test_config.py packages/core/tests/db/test_gateway_isolation.py packages/core/tests/db/test_gateway_migration.py services/ai-runtime/tests/test_gateway_execution.py services/ai-runtime/tests/test_gateway_completion.py services/ai-runtime/tests/test_gateway_adversarial.py services/ai-runtime/tests/test_gateway_attribution.py services/ai-runtime/tests/test_gateway_health.py services/ai-runtime/tests/test_gateway_resolvers.py services/ai-runtime/tests/test_gateway_security.py services/ai-runtime/tests/test_model_proxy.py services/ai-runtime/tests/test_provider_contracts.py services/ai-runtime/tests/test_router_contract.py services/ai-runtime/tests/test_suspension_at_model_boundary.py apps/api/tests/test_platform_gateway_api.py
	pnpm --filter @grobot/web exec vitest run src/lib/gateway.test.ts

router-test:  ## P-12.3 Intelligent Model Router: unit, evaluation, gateway integration, migration, platform + customer API, web helpers (no provider is called)
	uv run pytest -q -m "not docker" packages/core/tests/test_nimr_native.py packages/core/tests/test_nimr_evaluation.py packages/core/tests/db/test_router_migration.py services/ai-runtime/tests/test_router_nimr.py services/ai-runtime/tests/test_router_performance.py services/ai-runtime/tests/test_router_contract.py apps/api/tests/test_platform_router_api.py
	pnpm --filter @grobot/web exec vitest run src/lib/router.test.ts src/lib/platform.test.ts

router-eval:  ## reproducible routing evaluation over the fixture dataset (spends nothing)
	uv run python -m grobot_core.gateway.nimr.evaluation

key-gateway:  ## the key gateway on 127.0.0.1:8030: holds API keys from ./keys.toml so GRobot connections stay open
	uv run uvicorn grobot_key_gateway.main:app --host 127.0.0.1 --port 8030

mcp-test:  ## the M12 checks: MCP unit, DB, API, service, security and boundary tests (no containers)
	uv run pytest -q -m "not docker" packages/core/tests/test_mcp_primitives.py packages/core/tests/test_mcp_client.py packages/core/tests/test_mcp_network.py packages/core/tests/test_mcp_inventory.py packages/core/tests/test_import_boundaries.py packages/core/tests/db/test_mcp_gateway.py packages/core/tests/db/test_mcp_workflow.py apps/api/tests/test_mcp_servers.py apps/api/tests/test_mcp_settings.py services/mcp/tests

e2e:  ## end-to-end tests against the real web app, API and database (needs `make up`)
	GROBOT_E2E=1 uv run pytest e2e -x -q

e2e-preflight:  ## are Docker, PostgreSQL, Redis, tooling and the browser ready for the e2e suite?
	@uv run python e2e/preflight.py

verify-patches:  ## the pnpm patch of Next.js is the one in the lockfile and is applied to what the web app resolves
	node infrastructure/scripts/verify-patches.mjs

E2E_TARGET ?= e2e
E2E_RUN ?= e2e-runs/$(shell date +%Y%m%d-%H%M%S)
e2e-rc:  ## the whole browser suite against ONE production build; logs, resource samples, failure artifacts in e2e-runs/
	@mkdir -p $(E2E_RUN)
	GROBOT_E2E=1 GROBOT_E2E_WEB_MODE=prod GROBOT_E2E_STRICT=1 GROBOT_E2E_LOG_DIR="$(CURDIR)/$(E2E_RUN)" \
	GROBOT_AXE_JS="$$(ls node_modules/.pnpm/axe-core@*/node_modules/axe-core/axe.min.js | head -1 | xargs realpath)" \
	uv run pytest $(E2E_TARGET) -q -p no:cacheprovider -rfEs --junitxml="$(CURDIR)/$(E2E_RUN)/junit.xml" $(ARGS) > $(E2E_RUN)/pytest.log 2>&1; rc=$$?; tail -n 40 $(E2E_RUN)/pytest.log; exit $$rc

fmt:
	uv run ruff format .
	pnpm format

lint:
	uv run ruff check .
	pnpm lint

typecheck:
	uv run mypy packages apps services
	pnpm typecheck

test:
	uv run pytest
	pnpm test

check: lint typecheck test
	uv run ruff format --check .
	pnpm format:check

prod-check:  ## validate .env.production (names only, never values) before deploying: see docs/deploy-dokploy.md
	uv run python infrastructure/scripts/prod_check.py --env-file .env.production

prod-compose-check:  ## render and validate the production compose files with placeholder values
	cd infrastructure/docker && GROBOT_RELEASE=check POSTGRES_PASSWORD=x REDIS_PASSWORD=x MINIO_ROOT_PASSWORD=x docker compose -f compose.prod.yml config -q

release-candidate:  ## local gate for a release candidate (docs/saas-production-release-process.md): lint, types, tests, compose, migrations, dependency audit; stops at the first failure
	@git diff --quiet && git diff --cached --quiet || { echo "release-candidate: tracked files have uncommitted changes"; exit 1; }
	$(MAKE) check
	$(MAKE) prod-compose-check
	@test "$$(uv run alembic heads | grep -c '(head)')" = "1" || { echo "release-candidate: more than one Alembic head"; exit 1; }
	pnpm audit --prod
	@uv export --no-hashes --all-packages --frozen 2>/dev/null > $${TMPDIR:-/tmp}/grobot-rc-req.txt && uvx pip-audit -r $${TMPDIR:-/tmp}/grobot-rc-req.txt --no-deps --disable-pip
	@echo "release-candidate: local gate passed for $$(git rev-parse --short=12 HEAD). Still required: staging deploy, smoke_prod.py, financial and security checks, e2e (see the release process)."
