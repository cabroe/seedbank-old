-- Agent contexts: session persistence per agent (episodic, semantic, procedural, working)
CREATE TABLE IF NOT EXISTS agent_contexts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id    TEXT NOT NULL,
  memory_type TEXT NOT NULL CHECK (memory_type IN ('episodic', 'semantic', 'procedural', 'working')),
  payload     JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_contexts_agent_memory ON agent_contexts(agent_id, memory_type);
