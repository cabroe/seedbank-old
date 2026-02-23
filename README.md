# Neural Brain

Minimaler, lokaler semantischer Speicher für OpenClaw: Go + pgvector + GTE-Small (gte-go). Ein Prozess, ~70 MB Modell, kein Python/Ollama zur Laufzeit.

**API und Skill kompatibel mit [Vanar Neutron Memory](https://openclaw.vanarchain.com/guide-openclaw)** (gleiche Endpoints, gleiche CLI-Nutzung wie `vanar-neutron-memory`).

## Voraussetzungen

- Go 1.22+
- PostgreSQL mit [pgvector](https://github.com/pgvector/pgvector) (z. B. `pgvector/pgvector:pg16`)
- Einmalig: Python 3 + `pip install safetensors requests` für das Modell-Setup

## Schnellstart

### 1. Postgres starten (mit pgvector)

```bash
docker compose up -d
```

Verbindung: `postgres://neural-brain:neural-brain@localhost:5433/neural-brain?sslmode=disable`

### 2. GTE-Small-Modell erzeugen (einmalig)

```bash
./scripts/setup-model.sh
```

Das Script erstellt bei Bedarf eine `.venv` und installiert dort `safetensors` und `requests` – kein System-pip nötig (PEP 668).

Das Script lädt die Hugging-Face-Weights und konvertiert sie nach `models/gte-small.gtemodel`.

### 3. Konfiguration

```bash
cp .env.example .env
# Optional anpassen: DATABASE_URL, GTE_MODEL_PATH, PORT, DEDUP_THRESHOLD
```

### 4. Server starten

```bash
go build -o neural-brain .
./neural-brain
```

Standard-Port: **9124**.

**Als systemd-User-Dienst** (optional):

Startreihenfolge: Zuerst Postgres und Modell bereitstellen, dann Konfiguration, danach den Dienst starten:

```bash
make up                              # Postgres (pgvector) starten
./scripts/setup-model.sh             # GTE-Modell einmalig erzeugen
make env                             # .env aus .env.example anlegen
mkdir -p ~/.config/systemd/user
cp neural-brain.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now neural-brain
# Status: systemctl --user status neural-brain
```

Bei Exit-Code 1: `journalctl --user -u neural-brain -n 50 --no-pager` zeigt die Fehlermeldung (z. B. Modell fehlt, DB nicht erreichbar). Die Unit lädt optional `.env` (`EnvironmentFile=-...`); fehlt die Datei, nutzt der Prozess seine Defaults.

Die Unit nutzt `%h` (= dein Home); bei anderem Projektpfad die Pfade in `neural-brain.service` anpassen.

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
curl -X POST http://localhost:9124/seeds \
  -H "Content-Type: application/json" \
  -d '{"content": "User mag Go und React. Grüße aus München.", "metadata": {"source": "memory-collector"}}'
```

Antwort: `201 Created` + `{"id": 1}` oder `200 OK` + `{"id": 0, "skipped": 1}` bei Dedup.

### GET /search?q=...&limit=10&threshold=0.5

Semantische Suche. Optionale Parameter:

- `q` (erforderlich) – Suchanfrage
- `limit` (optional, Standard 10) – maximale Anzahl Treffer
- `threshold` (optional, 0–1) – nur Treffer mit `score >= threshold` zurückgeben

```bash
curl "http://localhost:9124/search?q=Programmiersprachen&limit=5"
curl "http://localhost:9124/search?q=Programmiersprachen&limit=10&threshold=0.5"
```

Antwort: JSON-Array mit `id`, `content`, `metadata`, `created_at`, `score` (Cosine-Similarity).

### POST /agent-contexts

Legt einen Agent-Context an (Session-Persistenz: episodic, semantic, procedural, working).

```bash
curl -X POST http://localhost:9124/agent-contexts \
  -H "Content-Type: application/json" \
  -d '{"agentId": "my-agent", "memoryType": "episodic", "payload": {"key": "value"}}'
```

Body: `agentId` (erforderlich), `memoryType` (erforderlich: `episodic` | `semantic` | `procedural` | `working`), `payload` (optional, Standard `{}`).  
Antwort: `201 Created` + `{"id": "<uuid>"}`.

### GET /agent-contexts?agentId=...&memoryType=...

Listet Agent-Contexts. `agentId` erforderlich, `memoryType` optional (Filter).

```bash
curl "http://localhost:9124/agent-contexts?agentId=my-agent"
curl "http://localhost:9124/agent-contexts?agentId=my-agent&memoryType=episodic"
```

Antwort: JSON-Array mit `id`, `agentId`, `memoryType`, `payload`, `createdAt`.

### GET /agent-contexts/{id}

Liefert einen einzelnen Agent-Context per ID. `404` wenn nicht gefunden.

```bash
curl "http://localhost:9124/agent-contexts/550e8400-e29b-41d4-a716-446655440000"
```

### GET /health

Health-Check (Modell + DB).

```bash
curl http://localhost:9124/health
```

### GET /stats

Liefert Aggregationen für das Mission-Control-Dashboard: `seedsCount`, `agentContextsCount`.

```bash
curl http://localhost:9124/stats
```

Antwort: `{"seedsCount": 42, "agentContextsCount": 7}`.

## Mission Control Dashboard

Ein einseitiges **AI Agent Mission Control Dashboard** (Dark Theme, „Bloomberg Terminal meets Gaming HUD“) liegt unter `web/dashboard.html`. Es zeigt Agent-Status, Live-Feed, Neural Brain-Metriken (Memory Seeds, Active Contexts), semantische Suche und Quick Actions (u. a. „Manual Memory Sync“).

**Starten:** Neural Brain wie oben starten (Port 9124). Dashboard per HTTP ausliefern (z. B. aus dem Projektroot):

```bash
python3 -m http.server 8080
# Dann im Browser: http://localhost:8080/web/dashboard.html
```

Oder aus dem `web/`-Ordner: `python3 -m http.server 8080` → `http://localhost:8080/dashboard.html`.

- **Neural Brain-API:** Das Dashboard spricht mit `http://localhost:9124` (GET `/search`, GET `/stats`, POST `/seeds`, POST `/agent-contexts`). CORS ist am Neural Brain-Server aktiviert (`Access-Control-Allow-Origin: *`). **Bei CORS-Fehlern im Browser:** Neural Brain neu bauen und neu starten (`go build -o neural-brain . && ./neural-brain`).
- **Agent-Status / Live-Feed:** Optional kann ein Status-Endpoint unter `http://localhost:3000/api/status` genutzt werden. Ist Port 3000 nicht belegt, erscheinen Mock-Agents und „—“ bei Win Rate / Cost / Tasks; die Neural Brain-Funktionen laufen unabhängig davon. Erwartetes JSON: `agents` (Array mit `name`, `emoji`, `status`, `currentTask`), `feed` oder `actions` (Array mit `timestamp`, `text`, `type`), optional `metrics` mit `winRate`, `monthlyCost`, `tasksToday`. Ist die URL nicht erreichbar, werden Platzhalter- bzw. Mock-Daten angezeigt.

## Projektstruktur

```
neural-brain/
├── go.mod, main.go
├── internal/
│   ├── embed.go   # gte-go: Load, Embed, EmbedBatch
│   ├── store.go   # pgvector: Insert, Search, Dedup, Counts
│   └── handler.go # HTTP: /seeds, /search, /health, /stats, /agent-contexts
├── web/
│   └── dashboard.html   # Mission Control Dashboard (Single-Page)
├── migrations/
│   ├── 001_seeds.sql
│   └── 002_agent_contexts.sql
├── models/        # .gtemodel (nicht im Repo), Setup via scripts/setup-model.sh
├── scripts/
│   └── setup-model.sh
├── skills/
│   └── neural-brain-memory/
│       ├── scripts/
│       │   └── neural-brain-memory.sh   # CLI: save, search, context-create/list/get
│       └── hooks/   # Auto-Recall, Auto-Capture
├── docker-compose.yml
└── .env.example
```

## CLI: neural-brain-memory.sh

Das Script bietet die gleiche Nutzung wie das [Neutron-Guide](https://openclaw.vanarchain.com/guide-openclaw) (`neutron-memory.sh`), nur gegen die lokale Neural Brain-API. Basis-URL: `NEURAL_BRAIN_URL` (Standard: `http://localhost:9124`).

```bash
# Health-Check
./scripts/neural-brain-memory.sh test

# Memory speichern (content, optional tag)
./scripts/neural-brain-memory.sh save "User prefers oat milk lattes from Blue Bottle every weekday morning" "User coffee preference"

# Semantische Suche (query, optional limit default 30, optional threshold default 0.5)
./scripts/neural-brain-memory.sh search "what do I know about blockchain" 10 0.5

# Agent-Context anlegen
./scripts/neural-brain-memory.sh context-create "my-agent" "episodic" '{"key":"value"}'

# Contexts auflisten (agentId, optional memoryType)
./scripts/neural-brain-memory.sh context-list "my-agent"
./scripts/neural-brain-memory.sh context-list "my-agent" episodic

# Einzelnen Context abrufen
./scripts/neural-brain-memory.sh context-get <uuid>
```

Optional: `jq` für sicheres JSON-Escaping; ohne `jq` wird eine einfache Escaping-Logik verwendet.
