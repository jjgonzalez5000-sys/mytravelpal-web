.DEFAULT_GOAL := help

BACKEND_DIR   := backend
MOBILE_DIR    := mobile
COMPOSE       := docker-compose -f $(BACKEND_DIR)/docker-compose.yml
OSRM_DATA     := $(BACKEND_DIR)/data/osrm
OSRM_READY    := $(OSRM_DATA)/osrm-graph.osrm.cell_metrics

PROD_API_URL  := https://mytravelpal-api.fly.dev
PROD_API_KEY  := 7637fb236013308ebf998843d924e15e56dce87457187e22a1a03c9c1e164d7a
PROD_SENTRY   := https://3c46e071b627ae7c6c5cb4592cadbf60@o4511977727590400.ingest.de.sentry.io/4511977749086288
APP_PACKAGE   := com.mytravelpal.mytravelpal
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
	@echo "    make mobile-local   flutter run against local backend ($(LOCAL_IP):8000)"
	@echo "    make mobile-prod    flutter build APK against Fly + install + rclone upload"
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
	  --dart-define=SENTRY_DSN=
	@echo ">>> uninstalling previous build (clean state)"
	@adb uninstall $(APP_PACKAGE) 2>&1 | tail -1
	cd $(MOBILE_DIR) && flutter install --debug
	@echo ">>> launching app"
	@adb shell monkey -p $(APP_PACKAGE) -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
	@echo ""
	@echo "  App launched.  Backend: http://$(LOCAL_IP):8000"
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

.PHONY: clean
clean:
	$(COMPOSE) down -v
