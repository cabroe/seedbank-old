---
name: Goal Hierarchy
description: Intrinsic motivation and evaluating actions against active goals via semantic search
---

# Goal Hierarchy

This skill forms the agent's intrinsic motivation. It manages a tree of active directives and provides a fast, offline vector-based evaluation tool to check if a proposed action aligns with the agent's core goals.

Goals are stored in Seedbank as standard seeds with the `["goal"]` tag.

## Scripts
- `goals.sh`: The core CLI.
  - `add "<title>" "<description>" [parent_id]`: Creates a new active goal.
  - `list [status]`: Lists goals (active, completed, or all).
  - `complete <seed_id>`: Marks a goal as completed.
  - `evaluate "<action>"`: Uses `gte-go` semantic vector search via the Seedbank API to calculate the cosine similarity between the proposed action and active goals. Returns a float score.

## Usage Guidelines
- Use `evaluate` before taking significant autonomous actions.
- A score > `0.85` generally indicates good alignment, while lower scores indicate the action is unrelated or potentially harmful to current directives.
