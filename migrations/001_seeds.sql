-- Seedbank: pgvector schema for semantic seeds (GTE-Small 384-dim, L2-normalized)
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS seeds (
  id         BIGSERIAL PRIMARY KEY,
  content    TEXT NOT NULL,
  embedding  vector(384) NOT NULL,
  metadata   JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Cosine similarity index (for L2-normalized vectors, cosine distance = <=>)
CREATE INDEX IF NOT EXISTS seeds_embedding_idx ON seeds
USING hnsw (embedding vector_cosine_ops);
