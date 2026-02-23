package store

import (
	"context"
	"encoding/json"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pgvector/pgvector-go"
	pgxvec "github.com/pgvector/pgvector-go/pgx"
)

// Seed is a stored item with content, embedding, and optional metadata.
type Seed struct {
	ID        int64           `json:"id"`
	Content   string          `json:"content"`
	Metadata  json.RawMessage `json:"metadata"`
	CreatedAt string          `json:"created_at,omitempty"`
	Score     float64         `json:"score,omitempty"` // similarity score for search results
}

// AgentContext is a session-scoped context for an agent (episodic, semantic, procedural, working).
type AgentContext struct {
	ID         string          `json:"id"`
	AgentID    string          `json:"agentId"`
	MemoryType string          `json:"memoryType"`
	Payload    json.RawMessage `json:"payload"`
	CreatedAt  string          `json:"createdAt,omitempty"`
}

// Store provides database operations for seeds.
type Store struct {
	pool           *pgxpool.Pool
	dedupThreshold float64 // 0 = disabled; e.g. 0.92 = skip if cosine sim > 0.92
}

// NewStore creates a Store using the given pool. AfterConnect must register pgvector types.
func NewStore(pool *pgxpool.Pool, dedupThreshold float64) *Store {
	return &Store{pool: pool, dedupThreshold: dedupThreshold}
}

// Insert adds a seed: embed content, optionally dedupe, then INSERT. Returns id or 0 if skipped (duplicate).
func (s *Store) Insert(ctx context.Context, content string, metadata json.RawMessage, embedding []float32) (int64, error) {
	vec := pgvector.NewVector(embedding)

	if s.dedupThreshold > 0 {
		var similarity float64
		var id int64
		err := s.pool.QueryRow(ctx,
			`SELECT id, (1 - (embedding <=> $1)) AS sim FROM seeds ORDER BY embedding <=> $1 LIMIT 1`,
			vec,
		).Scan(&id, &similarity)
		if err == nil && similarity >= s.dedupThreshold {
			// Semantic Upsert: Update timestamp and increment update_count in metadata
			_, err = s.pool.Exec(ctx,
				`UPDATE seeds SET 
					created_at = NOW(),
					metadata = jsonb_set(
						COALESCE(metadata, '{}'::jsonb), 
						'{update_count}', 
						(COALESCE(metadata->>'update_count', '0')::int + 1)::text::jsonb
					)
				 WHERE id = $1`,
				id,
			)
			if err != nil {
				return 0, err
			}
			return id, nil // return existing ID to indicate "updated"
		}
	}

	var id int64
	err := s.pool.QueryRow(ctx,
		`INSERT INTO seeds (content, embedding, metadata) VALUES ($1, $2, COALESCE($3::jsonb, '{}')) RETURNING id`,
		content, vec, metadata,
	).Scan(&id)
	if err != nil {
		return 0, err
	}
	return id, nil
}

// UpdateSeedMetadata updates metadata on an existing seed by shallow merging the given JSON.
func (s *Store) UpdateSeedMetadata(ctx context.Context, id int64, patch json.RawMessage) error {
	cmdTag, err := s.pool.Exec(ctx,
		`UPDATE seeds SET metadata = COALESCE(metadata, '{}'::jsonb) || $1 WHERE id = $2`,
		patch, id,
	)
	if err != nil {
		return err
	}
	if cmdTag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// GetSeed retrieves a single seed by its ID.
func (s *Store) GetSeed(ctx context.Context, id int64) (*Seed, error) {
	var se Seed
	var createdAt time.Time
	err := s.pool.QueryRow(ctx,
		`SELECT id, content, metadata, created_at FROM seeds WHERE id = $1`,
		id,
	).Scan(&se.ID, &se.Content, &se.Metadata, &createdAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil // Not found
		}
		return nil, err
	}
	se.CreatedAt = createdAt.Format(time.RFC3339)
	return &se, nil
}

// UpdateSeed fully overwrites a seed's content, metadata, and recalculates its embedding.
func (s *Store) UpdateSeed(ctx context.Context, id int64, content string, metadata json.RawMessage, embedding []float32) error {
	vec := pgvector.NewVector(embedding)
	cmdTag, err := s.pool.Exec(ctx,
		`UPDATE seeds SET content = $1, metadata = COALESCE($2::jsonb, '{}'), embedding = $3 WHERE id = $4`,
		content, metadata, vec, id,
	)
	if err != nil {
		return err
	}
	if cmdTag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// Search returns seeds nearest to the query embedding (cosine), limit rows.
// If seedIDs is not empty, limits search to those specific IDs.
func (s *Store) Search(ctx context.Context, queryEmbedding []float32, limit int, seedIDs []int64) ([]Seed, error) {
	if limit <= 0 {
		limit = 10
	}
	vec := pgvector.NewVector(queryEmbedding)

	var rows pgx.Rows
	var err error

	if len(seedIDs) > 0 {
		rows, err = s.pool.Query(ctx,
			`SELECT id, content, metadata, created_at, 1 - (embedding <=> $1) AS score
			 FROM seeds 
			 WHERE id = ANY($3)
			 ORDER BY embedding <=> $1 LIMIT $2`,
			vec, limit, seedIDs,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT id, content, metadata, created_at, 1 - (embedding <=> $1) AS score
			 FROM seeds 
			 ORDER BY embedding <=> $1 LIMIT $2`,
			vec, limit,
		)
	}

	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var seeds []Seed
	for rows.Next() {
		var se Seed
		var createdAt time.Time
		err := rows.Scan(&se.ID, &se.Content, &se.Metadata, &createdAt, &se.Score)
		if err != nil {
			return nil, err
		}
		se.CreatedAt = createdAt.Format(time.RFC3339)
		seeds = append(seeds, se)
	}
	return seeds, rows.Err()
}

// GetRecent returns the most recently created seeds, purely chronological, without vector search.
func (s *Store) GetRecent(ctx context.Context, limit int) ([]Seed, error) {
	if limit <= 0 {
		limit = 10
	}
	rows, err := s.pool.Query(ctx,
		`SELECT id, content, metadata, created_at, 0 AS score
		 FROM seeds ORDER BY created_at DESC LIMIT $1`,
		limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var seeds []Seed
	for rows.Next() {
		var se Seed
		var createdAt time.Time
		err := rows.Scan(&se.ID, &se.Content, &se.Metadata, &createdAt, &se.Score)
		if err != nil {
			return nil, err
		}
		se.CreatedAt = createdAt.Format(time.RFC3339)
		seeds = append(seeds, se)
	}
	return seeds, rows.Err()
}

// InsertContext adds an agent context and returns its ID.
func (s *Store) InsertContext(ctx context.Context, agentID, memoryType string, payload json.RawMessage) (string, error) {
	if payload == nil {
		payload = []byte("{}")
	}
	var id string
	err := s.pool.QueryRow(ctx,
		`INSERT INTO agent_contexts (agent_id, memory_type, payload) VALUES ($1, $2, COALESCE($3::jsonb, '{}')) RETURNING id::text`,
		agentID, memoryType, payload,
	).Scan(&id)
	if err != nil {
		return "", err
	}
	return id, nil
}

// ListContexts returns agent contexts for the given agentID (empty = all), optionally filtered by memoryType.
func (s *Store) ListContexts(ctx context.Context, agentID, memoryType string) ([]AgentContext, error) {
	var rows pgx.Rows
	var err error
	if agentID != "" && memoryType != "" {
		rows, err = s.pool.Query(ctx,
			`SELECT id::text, agent_id, memory_type, payload, created_at FROM agent_contexts WHERE agent_id = $1 AND memory_type = $2 ORDER BY created_at`,
			agentID, memoryType,
		)
	} else if agentID != "" {
		rows, err = s.pool.Query(ctx,
			`SELECT id::text, agent_id, memory_type, payload, created_at FROM agent_contexts WHERE agent_id = $1 ORDER BY created_at`,
			agentID,
		)
	} else if memoryType != "" {
		rows, err = s.pool.Query(ctx,
			`SELECT id::text, agent_id, memory_type, payload, created_at FROM agent_contexts WHERE memory_type = $1 ORDER BY created_at`,
			memoryType,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT id::text, agent_id, memory_type, payload, created_at FROM agent_contexts ORDER BY created_at`,
		)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []AgentContext
	for rows.Next() {
		var c AgentContext
		var createdAt time.Time
		err := rows.Scan(&c.ID, &c.AgentID, &c.MemoryType, &c.Payload, &createdAt)
		if err != nil {
			return nil, err
		}
		c.CreatedAt = createdAt.Format(time.RFC3339)
		list = append(list, c)
	}
	return list, rows.Err()
}

// SeedsCount returns the total number of seeds.
func (s *Store) SeedsCount(ctx context.Context) (int64, error) {
	var n int64
	err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM seeds`).Scan(&n)
	return n, err
}

// AgentContextsCount returns the total number of agent contexts.
func (s *Store) AgentContextsCount(ctx context.Context) (int64, error) {
	var n int64
	err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM agent_contexts`).Scan(&n)
	return n, err
}

// GetContext returns a single agent context by ID, or nil and error if not found.
func (s *Store) GetContext(ctx context.Context, id string) (*AgentContext, error) {
	var c AgentContext
	var createdAt time.Time
	err := s.pool.QueryRow(ctx,
		`SELECT id::text, agent_id, memory_type, payload, created_at FROM agent_contexts WHERE id = $1::uuid`,
		id,
	).Scan(&c.ID, &c.AgentID, &c.MemoryType, &c.Payload, &createdAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	c.CreatedAt = createdAt.Format(time.RFC3339)
	return &c, nil
}

// RunMigrations runs the SQL in migrations (e.g. 001_seeds.sql). Call once at startup if desired.
func RunMigrations(ctx context.Context, pool *pgxpool.Pool, sql string) error {
	_, err := pool.Exec(ctx, sql)
	return err
}

// PoolConfig returns a pgxpool.Config with AfterConnect registering pgvector types.
func PoolConfig(databaseURL string) (*pgxpool.Config, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, err
	}
	config.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
		return pgxvec.RegisterTypes(ctx, conn)
	}
	return config, nil
}
