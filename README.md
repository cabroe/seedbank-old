# Neural Brain

Minimaler, lokaler semantischer Speicher für OpenClaw: Go + pgvector + GTE-Small (gte-go). Ein Prozess, ~70 MB Modell, kein Python/Ollama zur Laufzeit. Das Projekt enthält zudem ein direkt in die Go-Binary kompiliertes React-Web-Dashboard.

**API und Skill kompatibel mit [Vanar Neutron Memory](https://openclaw.vanarchain.com/guide-openclaw)** (gleiche Endpoints, gleiche CLI-Nutzung wie `vanar-neutron-memory`).

## Voraussetzungen

- Go 1.22+
- NodeJS & npm (für das React-Frontend)
- PostgreSQL mit [pgvector](https://github.com/pgvector/pgvector) (z. B. `pgvector/pgvector:pg16`)
- Einmalig: Python 3 + `pip install safetensors requests numpy` für das Modell-Setup

## Schnellstart

### 1. Postgres starten (mit pgvector)

```bash
make db-up
```

Verbindung: `postgres://neural-brain:neural-brain@localhost:5433/neural-brain?sslmode=disable`

### 2. GTE-Small-Modell erzeugen (einmalig)

```bash
./scripts/setup-model.sh
```

Das Script erstellt bei Bedarf eine `.venv` und installiert dort `safetensors`, `requests` und `numpy` – kein System-pip nötig (PEP 668).
Das Script lädt dann die Hugging-Face-Weights herunter und konvertiert sie nach `models/gte-small.gtemodel`.

### 3. Konfiguration

```bash
cp .env.example .env
# Optional anpassen: DATABASE_URL, GTE_MODEL_PATH, PORT, DEDUP_THRESHOLD
```

### 4. Server & Dashboard starten

Da das Web-Dashboard fest in das Go-Backend integriert ist, muss es beim Start mitgebaut werden:

```bash
make run
```

Dieser Befehl baut das React-Frontend (`npm install`, `npm run build`), kompiliert die Go-Binary und startet den Server.

Das **Mission Control Dashboard** ist nun erreichbar unter: **[http://localhost:9124](http://localhost:9124)**

**Als systemd-User-Dienst** (optional):

```bash
make install
# Status prüfen:
make status
```

Bei Exit-Code 1: `make logs` zeigt die Fehlermeldung (z. B. Modell fehlt, DB nicht erreichbar). 

## Makefile Befehle

```bash
  make build      - Baut das Frontend (Vite) und das Backend (Go)
  make run        - Baut das Projekt und führt den Server im Vordergrund aus
  make dev        - Startet das Frontend im Dev-Modus (Hot-Reloading)
  make db-up      - Startet die Postgres-Datenbank via Docker
  make db-down    - Stoppt die Postgres-Datenbank
  make install    - Baut das Projekt und installiert den systemd-Dienst
  make logs       - Zeigt die Live-Logs des systemd-Dienstes
  make clean      - Stoppt den Dienst, löscht Binary und Build-Dateien
  make status     - Zeigt den Status von Dienst, API und Datenbank
```

## Umgebungsvariablen

| Variable          | Default                                      | Beschreibung |
|-------------------|----------------------------------------------|--------------|
| `DATABASE_URL`    | `postgres://neural-brain:neural-brain@localhost:5433/neural-brain?sslmode=disable` | PostgreSQL + pgvector |
| `GTE_MODEL_PATH`  | `./models/gte-small.gtemodel`                 | Pfad zum .gtemodel |
| `PORT`            | `9124`                                       | HTTP-Port |
| `DEDUP_THRESHOLD` | `0` (deaktiviert)                            | Wenn gesetzt (z. B. 0.92): Seeds mit Cosine-Similarity ≥ Schwellwert werden nicht erneut eingefügt |

## API

### POST /seeds
Speichert ein Seed (Text → Embedding → pgvector).
```bash
curl -X POST http://localhost:9124/seeds -H "Content-Type: application/json" -d '{"content": "User mag Go und React."}'
```

### GET /search?q=...&limit=10&threshold=0.5
Semantische Suche.

### GET /seeds/recent?limit=10
Chronologische Suche (neueste Einträge zuerst), ignoriert Vektor-Ähnlichkeit.

### POST & GET /agent-contexts
Speichert und listet Agent-Kontexte (Session-Persistenz: episodic, semantic, procedural, working).

### GET /stats
Liefert Aggregationen (Counts) aus der Datenbank, ideal für Metriken-Dashboards.
```bash
curl http://localhost:9124/stats
# Antwort: {"seeds": 42, "contexts": 7}
```

## Projektstruktur

```
neural-brain/
├── go.mod, main.go
├── internal/
│   ├── embed.go   # gte-go: Load, Embed, EmbedBatch
│   ├── store.go   # pgvector: Insert, Search, GetRecent, Counts
│   └── api/       # API Handler für Seeds und Contexts
├── backend/       # Vite React Frontend (Web-UI)
├── migrations/
├── models/        # .gtemodel via setup-model.sh
├── scripts/
├── skills/        # AI Skills (Metriken, Auto-Learning, Emotion, Goals etc.)
└── docker-compose.yml
```

## Skills: CLI & Hintergrund-Jobs

Das `skills/` Verzeichnis enthält eine Reihe von Shell-Skripten, die entweder interaktiv (wie `neural-brain-memory.sh`) oder als Hintergrund-Tasks (wie `auto-learning`, `emotion-engine`) agieren. Diese rufen OpenClaw-LLMs oder direkt die Neural Brain API auf. Alle können per OpenClaw YAML Konfiguration in den Agenten geladen werden.
