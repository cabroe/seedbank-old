.PHONY: help build run dev install logs db-up db-down clean status

help:
	@echo "=== Neural Brain Makefile ==="
	@echo "  make build      - Baut das Frontend (Vite) und das Backend (Go)"
	@echo "  make run        - Baut das Projekt und führt den Server im Vordergrund aus"
	@echo "  make dev        - Startet das Frontend im Dev-Modus (Hot-Reloading)"
	@echo "  make db-up      - Startet die Postgres-Datenbank via Docker"
	@echo "  make db-down    - Stoppt die Postgres-Datenbank"
	@echo "  make db-clean   - Löscht Docker-Container & Images (Daten/Volumes bleiben erhalten)"
	@echo "  make db-logs    - Zeigt die Live-Logs der Datenbank"
	@echo "  make install    - Baut das Projekt und installiert den systemd-Dienst"
	@echo "  make logs       - Zeigt die Live-Logs des systemd-Dienstes"
	@echo "  make clean      - Stoppt den Dienst, löscht Binary und Build-Dateien"
	@echo "  make status     - Zeigt den Status von Dienst, API und Datenbank"

db-up:
	docker compose up -d

db-down:
	docker compose stop

db-clean:
	docker compose down --rmi all

db-logs:
	docker compose logs -f postgres

build:
	npm install --prefix backend
	npm run build --prefix backend
	go build -o neural-brain .

run: build
	./neural-brain

dev:
	npm install --prefix backend
	npm run dev --prefix backend

install: build
	mkdir -p $$HOME/.config/systemd/user
	cp neural-brain.service $$HOME/.config/systemd/user/
	systemctl --user daemon-reload
	systemctl --user enable --now neural-brain
	systemctl --user restart neural-brain
	@echo "systemd-Dienst 'neural-brain' installiert und gestartet."

logs:
	journalctl --user -u neural-brain -n 50 -f

clean:
	-systemctl --user stop neural-brain 2>/dev/null || true
	rm -f neural-brain
	rm -rf backend/dist

status:
	@echo "=== Binary ==="
	@test -f neural-brain && ls -lh neural-brain || echo "Nicht vorhanden"
	@echo ""
	@echo "=== Datenbank ==="
	@docker compose ps 2>/dev/null || echo "Nicht erreichbar"
	@echo ""
	@echo "=== systemd-Dienst ==="
	@systemctl --user status neural-brain --no-pager 2>/dev/null || echo "Nicht aktiv"
	@echo ""
	@echo "=== API Health (localhost:9124) ==="
	@curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:9124/health 2>/dev/null || echo "Offline"
	@echo "" --no-pager
