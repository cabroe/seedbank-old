---
name: Neural Brain - Self-Reflection
description: Meta-cognition engine to extract Deep Beliefs from short-term memory
---

# Neural Brain - Self-Reflection

The Self-Reflection skill enables the agent to gather recent short-term memories and commit synthesized, high-level insights as persistent "Deep Beliefs" into long-term memory.

## Scripts
- `neural-brain-reflection.sh`: The core CLI.
  - `gather <hours>`: Retrieves recent Neural Brain memories from the last X hours.
  - `commit "<insight>" <importance> <confidence>`: Saves a new insight to the database, tagged as a `["reflection", "core-belief"]`.

## Usage Guidelines
- This skill relies on an external generative capabilities (either an LLM or the User) to actually "read" the `gather` output and "synthesize" the insight for the `commit` command.
- Assign high importance (1-10) and confidence (0.0-1.0) to core beliefs so they surface easily in future vector searches.
