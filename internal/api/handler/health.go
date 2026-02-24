package handler

import (
	"context"
	"net/http"

	apilib "github.com/cabroe/neural-brain/internal/api"
	"github.com/cabroe/neural-brain/internal/store"
	"github.com/cabroe/neural-brain/internal/model"
)

// HealthPinger is implemented by *pgxpool.Pool for health checks.
type HealthPinger interface {
	Ping(ctx context.Context) error
}

// HandleStats handles GET /stats: returns seedsCount and agentContextsCount for the dashboard.
func HandleStats(s *store.Store) http.HandlerFunc {
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
		apilib.RespondJSON(w, http.StatusOK, map[string]int64{"seedsCount": seedsCount, "agentContextsCount": contextsCount})
	}
}

// HandleHealth returns 200 if service is ready (model + DB).
func HandleHealth(pool HealthPinger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if model.Model() == nil {
			apilib.RespondError(w, http.StatusServiceUnavailable, "model not loaded")
			return
		}
		if pool != nil {
			if err := pool.Ping(r.Context()); err != nil {
				apilib.RespondError(w, http.StatusServiceUnavailable, "database unreachable")
				return
			}
		}
		apilib.RespondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}
