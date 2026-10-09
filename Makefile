.DEFAULT_GOAL := help

BACKEND_DIR   := backend
MOBILE_DIR    := mobile
COMPOSE       := docker-compose -f $(BACKEND_DIR)/docker-compose.yml
OSRM_DATA     := $(BACKEND_DIR)/data/osrm
OSRM_READY    := $(OSRM_DATA)/osrm-graph.osrm.cell_metrics

PROD_API_URL  := https://mytravelpal-api.fly.dev
PROD_API_KEY  := 7637fb236013308ebf998843d924e15e56dce87457187e22a1a03c9c1e164d7a
PROD_SENTRY   := https://3c46e071b627ae7c6c5cb4592cadbf60@o4511977727590400.ingest.de.sentry.io/4511977749086288
APP_PACKAGE   := com.mytravelpal.travel
APK_OUT       := $(MOBILE_DIR)/build/app/outputs/flutter-apk/app-release.apk
RCLONE_DEST   := blu3g3_drive_jjgonzalez5000:Desarrollo_APPS/APKs/

# Emulator sees the host as 10.0.2.2; physical device on wifi uses the
# host's LAN IP. `make mobile-local IP=192.168.1.42` overrides.
LOCAL_IP      ?= 10.0.2.2

.PHONY: help
help:
	@echo "MyTravelPal — dev commands"
	@echo ""
	@echo "  Local backend (dev, fast iteration):"
	@echo "    make osrm-prep      one-time: download PBFs + build OSRM graph (~30-60 min, ~15 GB disk)"
	@echo "    make dev            start local stack (api + db + redis + osrm) with hot reload"
	@echo "    make down           stop local stack"
	@echo "    make restart        recreate api container (picks up dependency changes)"
	@echo "    make logs           tail api + osrm logs"
	@echo "    make logs-api       tail api only"
	@echo "    make shell          bash inside api container"
	@echo "    make test           run backend tests inside api container (pytest -xvs -n auto)"
	@echo "    make ps             show running services"
	@echo "    make db-shell       psql into the local Postgres"
	@echo "    make redis-cli      redis-cli into the local Redis"
	@echo "    make osrm-check     smoke test local OSRM (Madrid -> Paris route)"
	@echo ""
	@echo "  Mobile:"
	@echo "    make mobile-local       build+install against local backend with AUTO_DEMO=1 (skips login)"
	@echo "    make mobile-local-clean same as mobile-local but WITHOUT AUTO_DEMO (real login flow)"
	@echo "    make mobile-prod        flutter build APK against Fly + install + rclone upload"
	@echo ""
	@echo "  Deploy (Fly):"
	@echo "    make deploy         fly deploy (production)"
	@echo ""
	@echo "  Housekeeping:"
	@echo "    make clean          docker-compose down -v (WARNING: wipes local Postgres data)"

.PHONY: osrm-prep
osrm-prep:
	@bash $(BACKEND_DIR)/scripts/osrm-prepare.sh

.PHONY: dev
dev: $(OSRM_READY)
	$(COMPOSE) up -d --build
	@echo ""
	@echo "  api:    http://localhost:8000/health"
	@echo "  osrm:   http://localhost:5000/route/v1/car/-3.7,40.4;2.35,48.85?overview=false"
	@echo "  db:     postgres://mytravelpal:mytravelpal@localhost:5432/mytravelpal"
	@echo "  redis:  redis://localhost:6379/0"
	@echo ""
	@echo "  Tail logs:  make logs"
	@echo "  Point mobile at this stack:  make mobile-local"

$(OSRM_READY):
	@echo ""
	@echo "!! OSRM graph not built yet. Run once:"
	@echo "    make osrm-prep"
	@echo ""
	@exit 1

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: restart
restart:
	$(COMPOSE) up -d --build --force-recreate api

.PHONY: logs
logs:
	$(COMPOSE) logs -f api osrm

.PHONY: logs-api
logs-api:
	$(COMPOSE) logs -f api

.PHONY: shell
shell:
	$(COMPOSE) exec api bash

.PHONY: test
test:
	$(COMPOSE) exec api pytest -xvs -n auto

.PHONY: ps
ps:
	$(COMPOSE) ps

.PHONY: db-shell
db-shell:
	$(COMPOSE) exec db psql -U mytravelpal -d mytravelpal

.PHONY: redis-cli
redis-cli:
	$(COMPOSE) exec redis redis-cli

.PHONY: osrm-check
osrm-check:
	@echo ">>> Madrid -> Paris via local OSRM"
	@curl -s "http://localhost:5000/route/v1/car/-3.7038,40.4168;2.3522,48.8566?overview=false" | python3 -c "import sys,json; r=json.load(sys.stdin); print(f'  distance: {r[\"routes\"][0][\"distance\"]/1000:.1f} km'); print(f'  duration: {r[\"routes\"][0][\"duration\"]/3600:.1f} h')"

.PHONY: mobile-local
mobile-local:
	cd $(MOBILE_DIR) && flutter build apk --debug --no-tree-shake-icons \
	  --dart-define=API_BASE_URL=http://$(LOCAL_IP):8000 \
	  --dart-define=API_KEY=devkey \
	  --dart-define=SENTRY_DSN= \
	  --dart-define=AUTO_DEMO=1
	@echo ">>> uninstalling previous build (clean state)"
	@adb uninstall $(APP_PACKAGE) 2>&1 | tail -1
	cd $(MOBILE_DIR) && flutter install --debug
	@echo ">>> launching app"
	@adb shell monkey -p $(APP_PACKAGE) -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
	@echo ""
	@echo "  App launched.  Backend: http://$(LOCAL_IP):8000  (AUTO_DEMO=1)"
	@echo "  Tail app logs: adb logcat | grep -iE 'mytravelpal|flutter'"
	@echo "  Tail backend:  make logs-api"

.PHONY: mobile-local-clean
mobile-local-clean:
	cd $(MOBILE_DIR) && flutter build apk --debug --no-tree-shake-icons \
	  --dart-define=API_BASE_URL=http://$(LOCAL_IP):8000 \
	  --dart-define=API_KEY=devkey \
	  --dart-define=SENTRY_DSN=
	@echo ">>> uninstalling previous build (clean state)"
	@adb uninstall $(APP_PACKAGE) 2>&1 | tail -1
	cd $(MOBILE_DIR) && flutter install --debug
	@echo ">>> launching app"
	@adb shell monkey -p $(APP_PACKAGE) -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
	@echo ""
	@echo "  App launched (no AUTO_DEMO).  Backend: http://$(LOCAL_IP):8000"
	@echo "  Tail app logs: adb logcat | grep -iE 'mytravelpal|flutter'"
	@echo "  Tail backend:  make logs-api"

.PHONY: mobile-prod
mobile-prod:
	cd $(MOBILE_DIR) && flutter build apk --release --no-shrink --no-tree-shake-icons \
	  --dart-define=API_BASE_URL=$(PROD_API_URL) \
	  --dart-define=API_KEY=$(PROD_API_KEY) \
	  --dart-define=SENTRY_DSN=$(PROD_SENTRY)
	@echo ">>> uninstalling previous build (clean state — user preference 2026-09-27)"
	@adb uninstall $(APP_PACKAGE) 2>&1 | tail -1
	cd $(MOBILE_DIR) && flutter install
	rclone copy $(APK_OUT) $(RCLONE_DEST)

.PHONY: deploy
deploy:
	cd $(BACKEND_DIR) && fly deploy

# --- Play Store screenshot capture --------------------------------
# Semi-auto: prompts you to navigate + snaps each with adb.
# Full-auto: `flutter drive` runs the demo end-to-end via
# `integration_test/screenshots_test.dart`. Both default to
# Spanish; override with `LOCALE=en`.
LOCALE ?= es
.PHONY: screenshots
screenshots:
	cd $(MOBILE_DIR) && ./tool/take_screenshots.sh $(LOCALE)

.PHONY: screenshots-auto
screenshots-auto:
	cd $(MOBILE_DIR) && ./tool/take_screenshots_auto.sh $(LOCALE)

# --- Google Play Console upload (fastlane) ------------------------
# Prereqs (one-time):
#   1. Ruby + bundler installed (`sudo apt install ruby-full`).
#   2. `cd mobile && bundle install` — pulls fastlane.
#   3. Google Cloud service account with Play Developer API access +
#      JSON key saved to `mobile/play-key.json` (gitignored).
#   4. That SA invited to Play Console → Users → Release manager.
#
# Typical flow:
#   make play-internal    # build AAB + upload to Internal track
#   make play-beta        # promote latest Internal → Closed testing
#   make play-prod        # promote latest Closed → Production
#
.PHONY: play-internal play-beta play-prod play-metadata play-pull
play-internal:
	cd $(MOBILE_DIR)/android && bundle exec fastlane internal

play-beta:
	cd $(MOBILE_DIR)/android && bundle exec fastlane promote_to_closed

play-prod:
	cd $(MOBILE_DIR)/android && bundle exec fastlane promote_to_prod

# Push the versioned store listing (icons, screenshots, descriptions).
# Edit files under mobile/android/fastlane/metadata/android/<locale>/
# then run this to sync to Play.
play-metadata:
	cd $(MOBILE_DIR)/android && bundle exec fastlane metadata

# One-off: snapshot whatever metadata is currently in Play Console
# into the repo. Run this after uploading any assets/text manually
# via the web UI so the repo becomes the source of truth.
play-pull:
	cd $(MOBILE_DIR)/android && bundle exec fastlane pull_metadata

# --- E2E smoke tests (Maestro) -------------------------------------------
# Prereqs: Maestro installed (~/.maestro/bin/maestro), emulator or device
# running, app NOT installed (script does fresh install each run).
# Usage: make e2e [DEVICE=emulator-5554]
.PHONY: e2e
e2e:
	cd $(MOBILE_DIR) && bash scripts/e2e.sh

# Run a single flow: make e2e-flow FLOW=plan_basic
.PHONY: e2e-flow
e2e-flow:
	maestro test $(MOBILE_DIR)/maestro/flows/$(FLOW).yaml

# --- Admin dashboard (Grafana + Fly proxy, one compose stack) ------
#
# Prereqs: `dashboard/.env` filled from `.env.example` with the
# Postgres user + password and a FLY_API_TOKEN. The stack runs the
# `flyctl proxy` tunnel itself (service `fly-proxy`), so there is no
# separate proxy to start. See `dashboard/README.md`.
#
# Port 5432 on localhost must be free: do not run `flyctl proxy 5432`
# by hand at the same time.
#
.PHONY: dashboard-up dashboard-down dashboard-logs
dashboard-up:
	@if ss -tln 2>/dev/null | grep -q ':5432 ' && \
	   ! docker ps --format '{{.Names}}' | grep -q '^mytravelpal-db-proxy$$'; then \
	  echo "localhost:5432 is already in use (a manual 'flyctl proxy'?). Stop it first."; \
	  exit 1; \
	fi
	cd dashboard && docker compose up -d
	@echo "Grafana up at http://localhost:3007 (admin / admin)"

dashboard-down:
	cd dashboard && docker compose down

dashboard-logs:
	cd dashboard && docker compose logs -f --tail=100

.PHONY: clean
clean:
	$(COMPOSE) down -v
