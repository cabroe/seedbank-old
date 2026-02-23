---
name: Neural Brain - Auto Learning
description: Autonomous learning and knowledge generation
disable-model-invocation: true
---

# Neural Brain - Auto Learning

This skill allows the agent to autonomously learn from its past interactions and thoughts by searching for patterns and saving new insights as semantic memories.

## Scripts
- `bash {baseDir}/scripts/neural-brain-auto-learning.sh`: Periodically triggered learning cycle that fetches recent memories and generates new insights using the configured LLM.
