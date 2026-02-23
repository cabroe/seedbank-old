---
name: Emotion Engine
description: Affect Simulation via V-A-D (Valence, Arousal, Dominance) tracking
---

# Emotion Engine

The Emotion Engine allows the agent to track, update, and retrieve its current affective state over time using the Neural Brain API's `working` memory contexts.

It models emotion on three axes:
1. **Valence** (0.0 to 10.0): How positive or negative the emotion is.
2. **Arousal** (0.0 to 10.0): How calm or excited the emotion is.
3. **Dominance** (0.0 to 10.0): How in-control or submissive the emotion feels.

## Scripts
- `emotion.sh`: The core CLI.
  - `get <agent_id>`: Retrieves the current emotion.
  - `set <agent_id> <V> <A> <D> "<reason>"`: Hard-sets the emotion.
  - `shift <agent_id> <dV> <dA> <dD> "<reason>"`: Applies a delta shift to the current emotion.

## Usage Guidelines
- Always use `shift` to smoothly transition emotions based on recent events (e.g., success = positive valence and dominance, failure = negative valence).
- The baseline emotion if no history exists is `(5.0, 5.0, 5.0)`.
