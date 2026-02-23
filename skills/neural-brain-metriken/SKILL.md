---
name: Neural Brain - Metriken
description: System metrics and activity tracking
disable-model-invocation: true
---

# Neural Brain - Metriken

This skill tracks and summarizes the agent's recent activity, memory counts, and emotional states, providing a high-level overview of the system's operational health and processing volume.

## Scripts
- `bash {baseDir}/scripts/neural-brain-metriken.sh`: Periodically triggered script that queries the database for statistics and logs them.
