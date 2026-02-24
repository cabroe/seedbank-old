package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"mime/multipart"

	"github.com/jackc/pgx/v5"
	apilib "github.com/cabroe/neural-brain/internal/api"
	"github.com/cabroe/neural-brain/internal/store"
	"github.com/cabroe/neural-brain/internal/model"
)

// HandleStoreSeed handles POST /seeds: JSON body or Neutron-style multipart form.
func HandleStoreSeed(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}

		var content string
		var metadata json.RawMessage = []byte("{}")

		ct := r.Header.Get("Content-Type")
		if strings.HasPrefix(ct, "multipart/form-data") {
			if err := r.ParseMultipartForm(10 << 20); err != nil {
				apilib.RespondError(w, http.StatusBadRequest, "invalid multipart form")
				return
			}
			content = parseMultipartText(r.MultipartForm, "text")
			source := parseMultipartText(r.MultipartForm, "textSources")
			if source == "" {
				source = "bot_save"
			}
			title := parseMultipartText(r.MultipartForm, "textTitles")
			if title == "" {
				title = "Untitled"
			}
			metadata, _ = json.Marshal(map[string]string{"source": source, "tag": title})
		} else {
			var req apilib.StoreSeedRequest
			if err := apilib.DecodeJSON(r, &req); err != nil {
				apilib.RespondError(w, http.StatusBadRequest, "invalid JSON")
				return
			}
			content = req.Content
			if req.Metadata != nil {
				metadata = req.Metadata
			}
		}

		if content == "" {
			apilib.RespondError(w, http.StatusBadRequest, "content required")
			return
		}

		appID := r.URL.Query().Get("appId")
		externalUserID := r.URL.Query().Get("externalUserId")

		emb, err := model.Embed(content)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		id, err := s.Insert(r.Context(), content, metadata, emb, appID, externalUserID)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		// Check if it was an "upsert" (returning existing ID where we previously returned 0)
		// We need to check if we can differentiate. In the current store logic, 
		// Insert returns the ID. If it's a duplicate, it returns the *existing* ID.
		// To know if it's NEW or UPDATED, we'd need to change the store signature 
		// or do another check. Let's simplify and just say 200 OK for everything 
		// but check if we can improve the UX.
		
		// Actually, let's look at the database. If we want to know if it was 
		// an insert or update, we should return a boolean from store.
		
		apilib.RespondJSON(w, http.StatusOK, map[string]interface{}{"id": id})
	}
}

// HandleSearch handles GET /search?q=...&limit=...&threshold=...&seedIds=1,2,3
func HandleSearch(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		q := r.URL.Query().Get("q")
		if q == "" {
			apilib.RespondError(w, http.StatusBadRequest, "q required")
			return
		}
		limit, threshold := parseSearchParams(r.URL.Query().Get("limit"), r.URL.Query().Get("threshold"))
		
		var seedIDs []int64
		if sids := r.URL.Query().Get("seedIds"); sids != "" {
			parts := strings.Split(sids, ",")
			for _, p := range parts {
				if id, err := strconv.ParseInt(strings.TrimSpace(p), 10, 64); err == nil {
					seedIDs = append(seedIDs, id)
				}
			}
		}

		appID := r.URL.Query().Get("appId")
		externalUserID := r.URL.Query().Get("externalUserId")

		seeds, err := runSearch(s, r, q, limit, threshold, seedIDs, appID, externalUserID)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if seeds == nil {
			seeds = []store.Seed{}
		}
		apilib.RespondJSON(w, http.StatusOK, seeds)
	}
}

// HandleGetRecent handles GET /seeds/recent?limit=...
func HandleGetRecent(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		limitStr := r.URL.Query().Get("limit")
		limit, _ := parseSearchParams(limitStr, "")
		
		appID := r.URL.Query().Get("appId")
		externalUserID := r.URL.Query().Get("externalUserId")
		
		seeds, err := s.GetRecent(r.Context(), limit, appID, externalUserID)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if seeds == nil {
			seeds = []store.Seed{}
		}
		apilib.RespondJSON(w, http.StatusOK, seeds)
	}
}

// HandleSeedsQuery handles POST /seeds/query (Neutron-compatible).
func HandleSeedsQuery(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		var req apilib.SeedsQueryRequest
		if err := apilib.DecodeJSON(r, &req); err != nil {
			apilib.RespondError(w, http.StatusBadRequest, "invalid JSON")
			return
		}
		if req.Query == "" {
			apilib.RespondError(w, http.StatusBadRequest, "query required")
			return
		}
		limit := req.Limit
		if limit <= 0 {
			limit = 30
		}
		if limit > 100 {
			limit = 100
		}
		threshold := req.Threshold
		if threshold < 0 {
			threshold = -1
		}
		appID := r.URL.Query().Get("appId")
		externalUserID := r.URL.Query().Get("externalUserId")

		seeds, err := runSearch(s, r, req.Query, limit, threshold, req.SeedIDs, appID, externalUserID)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		results := make([]apilib.SeedQueryResult, 0, len(seeds))
		for _, se := range seeds {
			results = append(results, apilib.SeedQueryResult{
				SeedID:     strconv.FormatInt(se.ID, 10),
				Content:    se.Content,
				Similarity: se.Score,
			})
		}
		if results == nil {
			results = []apilib.SeedQueryResult{}
		}
		apilib.RespondJSON(w, http.StatusOK, map[string]interface{}{"results": results})
	}
}

// HandleUpdateSeedMetadata handles PATCH /seeds/{id}/metadata.
func HandleUpdateSeedMetadata(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPatch {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		idStr := r.PathValue("id")
		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil || id <= 0 {
			apilib.RespondError(w, http.StatusBadRequest, "invalid id")
			return
		}

		var patch json.RawMessage
		if err := apilib.DecodeJSON(r, &patch); err != nil {
			apilib.RespondError(w, http.StatusBadRequest, "invalid JSON")
			return
		}

		err = s.UpdateSeedMetadata(r.Context(), id, patch)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		
		apilib.RespondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}

// HandleUpdateSeedTags handles POST /seeds/{id}/tags.
func HandleUpdateSeedTags(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		idStr := r.PathValue("id")
		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil || id <= 0 {
			apilib.RespondError(w, http.StatusBadRequest, "invalid id")
			return
		}

		var tags []string
		if err := apilib.DecodeJSON(r, &tags); err != nil {
			apilib.RespondError(w, http.StatusBadRequest, "invalid JSON array of tags")
			return
		}

		patchObj := map[string][]string{"tags": tags}
		patchBytes, _ := json.Marshal(patchObj)

		err = s.UpdateSeedMetadata(r.Context(), id, patchBytes)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		apilib.RespondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}

// HandleGetSeed handles GET /seeds/{id}.
func HandleGetSeed(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		idStr := r.PathValue("id")
		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil || id <= 0 {
			apilib.RespondError(w, http.StatusBadRequest, "invalid id")
			return
		}

		seed, err := s.GetSeed(r.Context(), id)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if seed == nil {
			apilib.RespondError(w, http.StatusNotFound, "not found")
			return
		}

		apilib.RespondJSON(w, http.StatusOK, seed)
	}
}

// HandleGetStats handles GET /stats.
func HandleGetStats(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}

		seedsCount, err := s.SeedsCount(r.Context())
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		contextsCount, err := s.AgentContextsCount(r.Context())
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		apilib.RespondJSON(w, http.StatusOK, map[string]int64{
			"seeds":          seedsCount,
			"agent_contexts": contextsCount,
		})
	}
}

// HandleUpdateSeed handles PUT /seeds/{id} for full overwriting.
func HandleUpdateSeed(s *store.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut {
			apilib.RespondError(w, http.StatusMethodNotAllowed, "method not allowed")
			return
		}
		idStr := r.PathValue("id")
		id, err := strconv.ParseInt(idStr, 10, 64)
		if err != nil || id <= 0 {
			apilib.RespondError(w, http.StatusBadRequest, "invalid id")
			return
		}

		var req apilib.StoreSeedRequest
		if err := apilib.DecodeJSON(r, &req); err != nil {
			apilib.RespondError(w, http.StatusBadRequest, "invalid JSON")
			return
		}
		if req.Content == "" {
			apilib.RespondError(w, http.StatusBadRequest, "content required")
			return
		}

		emb, err := model.Embed(req.Content)
		if err != nil {
			apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			return
		}

		metadata := req.Metadata
		if metadata == nil {
			metadata = []byte("{}")
		}

		appID := r.URL.Query().Get("appId")
		externalUserID := r.URL.Query().Get("externalUserId")

		err = s.UpdateSeed(r.Context(), id, req.Content, metadata, emb, appID, externalUserID)
		if err != nil {
			if err == pgx.ErrNoRows {
				apilib.RespondError(w, http.StatusNotFound, "not found")
			} else {
				apilib.RespondError(w, http.StatusInternalServerError, err.Error())
			}
			return
		}

		apilib.RespondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}

// Helper functions

func parseMultipartText(form *multipart.Form, key string) string {
	if form == nil || form.Value == nil {
		return ""
	}
	vals := form.Value[key]
	if len(vals) == 0 {
		return ""
	}
	s := strings.TrimSpace(vals[0])
	if s == "" {
		return ""
	}
	if (strings.HasPrefix(s, "[") && strings.HasSuffix(s, "]")) || strings.HasPrefix(s, "[\"") {
		var arr []string
		if err := json.Unmarshal([]byte(s), &arr); err == nil && len(arr) > 0 {
			return arr[0]
		}
	}
	return s
}

func parseSearchParams(limitStr, thresholdStr string) (limit int, threshold float64) {
	limit = 30
	if l := limitStr; l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 {
			limit = n
		}
	}
	threshold = -1
	if t := thresholdStr; t != "" {
		if v, err := strconv.ParseFloat(t, 64); err == nil && v >= 0 && v <= 1 {
			threshold = v
		}
	}
	return limit, threshold
}

func runSearch(s *store.Store, r *http.Request, q string, limit int, threshold float64, seedIDs []int64, appID, externalUserID string) ([]store.Seed, error) {
	emb, err := model.Embed(q)
	if err != nil {
		return nil, err
	}
	seeds, err := s.Search(r.Context(), emb, limit, seedIDs, appID, externalUserID)
	if err != nil {
		return nil, err
	}
	if threshold >= 0 {
		filtered := seeds[:0]
		for _, se := range seeds {
			if se.Score >= threshold {
				filtered = append(filtered, se)
			}
		}
		seeds = filtered
	}
	return seeds, nil
}
