.PHONY: help up down down-all model env build run test install install-service install-skill reinstall status logs clean dev install-ui

help:
	@echo "Neural Brain – wichtige Befehle"
	@echo "  make install         Build + Docker-Image + Unit + Skill installieren"
	@echo "  make reinstall       clean, install, Docker (Postgres) starten"
	@echo "  make dev             Vite-Frontend im Dev-Mode starten"
	@echo "  make install-ui      Frontend-Abhaengigkeiten (npm) installieren"
	@echo "  make status          Uebersicht: Binary, Docker, systemd, Skill, Health"
	@echo "  make clean           Docker (down -v --rmi all), systemd-Dienst deaktivieren/entfernen, Binary loeschen"
	@echo "  make up              Postgres (pgvector) starten"
	@echo "  make down            Postgres stoppen"
	@echo "  make down-all        Down + Volumes + Images loeschen"
	@echo "  make model           GTE-Small-Modell einmalig einrichten"
	@echo "  make env             .env aus .env.example anlegen"
	@echo "  make build           Binary + Docker-Image bauen"
	@echo "  make run             Build + Server im Vordergrund"
	@echo "  make test            Neural Brain-Health (Server muss laufen)"
	@echo "  make install-service systemd User-Unit installieren"
	@echo "  make install-skill   Skill neural-brain-memory nach ~/.openclaw/workspace/skills/ kopieren"
	@echo "  make logs            Journal folgen (tail -f, Strg+C zum Beenden)"

up:
	docker compose up -d

down:
	docker compose down

docker: up

down-all:
	docker compose down -v --rmi all

clean:
	docker compose down -v --rmi all
	-systemctl --user stop neural-brain 2>/dev/null || true
	-systemctl --user disable neural-brain 2>/dev/null || true
	rm -f $$HOME/.config/systemd/user/neural-brain.service
	systemctl --user daemon-reload 2>/dev/null || true
	rm -f neural-brain

model:
	./scripts/setup-model.sh

env:
	cp .env.example .env

build:
	go build -o neural-brain .
	docker build -t neural-brain:latest .

install: build install-service install-skill

reinstall: clean install up

run: build
	./neural-brain

dev:
	npm run dev --prefix backend

install-ui:
	npm install --prefix backend

test:
	./skills/neural-brain-memory/scripts/neural-brain-memory.sh test

install-service:
	mkdir -p $$HOME/.config/systemd/user
	cp neural-brain.service $$HOME/.config/systemd/user/
	systemctl --user daemon-reload
	systemctl --user enable neural-brain
	systemctl --user restart neural-brain
	@echo "Status: systemctl --user status neural-brain"

install-skill:
	mkdir -p $$HOME/.openclaw/workspace/skills
	cp -R skills/neural-brain-memory $$HOME/.openclaw/workspace/skills/

status:
	@echo "=== Binary ==="
	@test -f neural-brain && ls -la neural-brain || echo "nicht vorhanden"
	@echo ""
	@echo "=== Docker (Compose) ==="
	@docker compose ps 2>/dev/null || echo "nicht erreichbar / kein Projekt"
	@echo ""
	@echo "=== systemd (neural-brain) ==="
	@systemctl --user status neural-brain --no-pager 2>/dev/null || echo "Unit nicht geladen"
	@echo ""
	@echo "=== Skill (OpenClaw) ==="
	@test -d $$HOME/.openclaw/workspace/skills/neural-brain-memory && echo "installiert: $$HOME/.openclaw/workspace/skills/neural-brain-memory" || echo "nicht installiert"
	@echo ""
	@echo "=== Health (localhost:9124) ==="
	@code=$$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9124/health 2>/dev/null); test -n "$$code" && echo "HTTP $$code" || echo "nicht erreichbar"

logs:
	journalctl --user -u neural-brain -n 50 -f --no-pager
