-- Migration to add multi-tenancy support
ALTER TABLE seeds ADD COLUMN IF NOT EXISTS app_id TEXT;
ALTER TABLE seeds ADD COLUMN IF NOT EXISTS external_user_id TEXT;

ALTER TABLE agent_contexts ADD COLUMN IF NOT EXISTS app_id TEXT;
ALTER TABLE agent_contexts ADD COLUMN IF NOT EXISTS external_user_id TEXT;

CREATE INDEX IF NOT EXISTS idx_seeds_multi_tenancy ON seeds(app_id, external_user_id);
CREATE INDEX IF NOT EXISTS idx_agent_contexts_multi_tenancy ON agent_contexts(app_id, external_user_id);
