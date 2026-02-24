package handler

import (
	"encoding/json"
	"net/http"
	"strings"

	apilib "github.com/cabroe/neural-brain/internal/api"
	"github.com/cabroe/neural-brain/internal/store"
)

var validMemoryTypes = map[string]bool{
	"episodic": true, "semantic": true, "procedural": true, "working": true,
}

// HandleCreateContext handles POST /agent-contexts: create an agent context.
func HandleCreateContext(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		var req apilib.CreateContextRequest
		if err := apilib.DecodeJSON(r, &req); err != nil {
			apilib.RespondError(w, http.StatusBadRequest, "invalid JSON")
			return
		}
		req.AgentID = strings.TrimSpace(req.AgentID)
		if req.AgentID == "" {
			apilib.RespondError(w, http.StatusBadRequest, "agentId required")
			return
		}
		req.MemoryType = strings.TrimSpace(strings.ToLower(req.MemoryType))
		if !validMemoryTypes[req.MemoryType] {
			apilib.RespondError(w, http.StatusBadRequest, "memoryType must be one of: episodic, semantic, procedural, working")
			return
		}
		payload := req.Payload
		if payload == nil || len(payload) == 0 {
			payload = req.Data
		}
		if payload == nil || len(payload) == 0 {
			payload = []byte("{}")
		}
		if req.Metadata != nil && len(req.Metadata) > 0 && string(req.Metadata) != "{}" {
			// Merge metadata into payload for Neutron compatibility
			var pl map[string]interface{}
			if json.Unmarshal(payload, &pl) == nil {
				var meta map[string]interface{}
				if json.Unmarshal(req.Metadata, &meta) == nil {
					for k, v := range meta {
						pl["metadata_"+k] = v
					}
					payload, _ = json.Marshal(pl)
				}
			}
		}
		appID := r.URL.Query().Get("appId")
		externalUserID := r.URL.Query().Get("externalUserId")

		id, err := s.InsertContext(r.Context(), req.AgentID, req.MemoryType, payload, appID, externalUserID)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		apilib.RespondJSON(w, http.StatusCreated, map[string]string{"id": id})
	}
}

// HandleListContexts handles GET /agent-contexts?agentId=...&memoryType=...
func HandleListContexts(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		agentID := strings.TrimSpace(r.URL.Query().Get("agentId"))
		memoryType := strings.TrimSpace(strings.ToLower(r.URL.Query().Get("memoryType")))
		if memoryType != "" && !validMemoryTypes[memoryType] {
			apilib.RespondError(w, http.StatusBadRequest, "memoryType must be one of: episodic, semantic, procedural, working")
			return
		}
		appID := r.URL.Query().Get("appId")
		externalUserID := r.URL.Query().Get("externalUserId")

		list, err := s.ListContexts(r.Context(), agentID, memoryType, appID, externalUserID)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if list == nil {
			list = []store.AgentContext{}
		}
		apilib.RespondJSON(w, http.StatusOK, list)
	}
}

// HandleGetContext handles GET /agent-contexts/{id}.
func HandleGetContext(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		id := r.PathValue("id")
		if id == "" {
			apilib.RespondError(w, http.StatusBadRequest, "id required")
			return
		}
		c, err := s.GetContext(r.Context(), id)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if c == nil {
			apilib.RespondError(w, http.StatusNotFound, "not found")
			return
		}
		apilib.RespondJSON(w, http.StatusOK, c)
	}
}
