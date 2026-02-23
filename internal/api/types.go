package api

import "encoding/json"

// StoreSeedRequest is the JSON body for POST /seeds.
type StoreSeedRequest struct {
	Content  string          `json:"content"`
	Metadata json.RawMessage `json:"metadata"`
}

// SeedsQueryRequest is the JSON body for POST /seeds/query (Neutron-compatible).
type SeedsQueryRequest struct {
	Query     string  `json:"query"`
	Limit     int     `json:"limit"`
	Threshold float64 `json:"threshold"`
	SeedIDs   []int64 `json:"seedIds,omitempty"`
}

// SeedQueryResult is a Neutron-style result item: seedId, content, similarity.
type SeedQueryResult struct {
	SeedID     string  `json:"seedId"`
	Content    string  `json:"content"`
	Similarity float64 `json:"similarity"`
}

// CreateContextRequest is the JSON body for POST /agent-contexts (Neutron uses data/metadata, we accept payload or data).
type CreateContextRequest struct {
	AgentID    string          `json:"agentId"`
	MemoryType string          `json:"memoryType"`
	Payload    json.RawMessage `json:"payload"`
	Data       json.RawMessage `json:"data"`
	Metadata   json.RawMessage `json:"metadata"`
}
