---
name: neural-brain-memory
description: Store and retrieve agent memory using Neural Brain (local API). Semantic search, auto-recall, and multi-tenancy support.
user-invocable: true
metadata: {"openclaw": {"emoji": "🧠", "requires": {"env": ["NEURAL_BRAIN_URL", "NEURAL_BRAIN_AGENT_ID"]}, "primaryEnv": "NEURAL_BRAIN_URL"}}
---

# Neural Brain Memory

Local, high-performance semantic memory storage for AI agents. Built with Go and pgvector, utilizing GTE-Small for embeddings. Fully compatible with the OpenClaw / Vanar Neutron specification.

## Features

- **Auto-Recall**: Automatically queries relevant memories before each AI turn and injects them as context.
- **Auto-Capture**: Automatically saves conversation fragments after each AI turn to build long-term knowledge.
- **Local Embedding**: Zero-latency semantic search using a local GTE-Small model (no external API calls).
- **Multi-Tenancy**: Support for `appId` and `externalUserId` to isolate memories between different agents and users.
- **Memory Types**: Full support for episodic, semantic, procedural, and working memory contexts.

## Setup

Neural Brain Memory runs against your local Neural Brain instance. By default, it looks for the API at `http://localhost:9124`.

Environment variables:
```bash
export NEURAL_BRAIN_URL=http://localhost:9124
export NEURAL_BRAIN_AGENT_ID=your_agent_id
export NEURAL_BRAIN_EXTERNAL_USER_ID=your_user_id
```

Or stored in `~/.config/neural-brain/credentials.json`:
```json
{
  "url": "http://localhost:9124",
  "agent_id": "your_agent_id_here",
  "external_user_id": "your_user_id_here",
  "auto_recall": true,
  "auto_capture": true
}
```

## Testing

Verify your setup:
```bash
./scripts/neural-brain-memory.sh test  # Test API connection
```

## Hooks (Auto-Capture & Auto-Recall)

The skill includes OpenClaw hooks for automatic memory management:

- `hooks/pre-tool-use.sh` - **Auto-Recall**: Queries memories before AI turn, injects relevant context.
- `hooks/post-tool-use.sh` - **Auto-Capture**: Saves conversation after AI turn.

### Configuration

Both features are **enabled by default**. To disable:

```bash
export NEURAL_BRAIN_AUTO_RECALL=false   # Disable auto-recall
export NEURAL_BRAIN_AUTO_CAPTURE=false  # Disable auto-capture
```

## Scripts

Use the provided bash script for manual operations:
- `neural-brain-memory.sh` - Main CLI tool.

## Common Operations

### Save Text as a Seed
```bash
./scripts/neural-brain-memory.sh save "Content to remember" "Title of this memory"
```

### Semantic Search
```bash
./scripts/neural-brain-memory.sh search "what are the user's coding preferences?" 10 0.5
```

### Create Agent Context
```bash
./scripts/neural-brain-memory.sh context-create "my-agent" "episodic" '{"key":"value"}'
```

### List Agent Contexts
```bash
./scripts/neural-brain-memory.sh context-list "my-agent"
```

### Get Specific Context
```bash
./scripts/neural-brain-memory.sh context-get abc-123
```

## API Compatibility

This skill is a drop-in replacement for `vanar-neutron-memory`. It uses the same endpoint patterns:

- `POST /seeds` - Save text content
- `POST /seeds/query` - Semantic search
- `POST /agent-contexts` - Create agent context
- `GET /agent-contexts` - List contexts
- `GET /agent-contexts/{id}` - Get specific context

**Note**: Unlike the official Neutron API, Neural Brain **does not require** an API key or Bearer token for local development.
