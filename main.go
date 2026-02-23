package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/cabroe/seedbank/internal/api/handler"
	"github.com/cabroe/seedbank/internal/model"
	"github.com/cabroe/seedbank/internal/store"
)

// responseWriter captures status for logging.
type responseWriter struct {
	http.ResponseWriter
	status int
}

func (w *responseWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func main() {
	modelPath := os.Getenv("GTE_MODEL_PATH")
	if modelPath == "" {
		modelPath = "./models/gte-small.gtemodel"
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "9124"
	}
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		databaseURL = "postgres://seedbank:seedbank@localhost:5433/seedbank?sslmode=disable"
	}
	dedupThreshold := 0.0
	if s := os.Getenv("DEDUP_THRESHOLD"); s != "" {
		if v, err := strconv.ParseFloat(s, 64); err == nil && v >= 0 {
			dedupThreshold = v
		}
	}

	if _, err := model.LoadModel(modelPath); err != nil {
		log.Fatalf("load model: %v", err)
	}
	defer model.CloseModel()
	log.Println("model loaded")

	// Bootstrap pool (no pgvector): ping and run migrations so CREATE EXTENSION vector runs first.
	bootConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		log.Fatalf("parse database config: %v", err)
	}
	bootPool, err := pgxpool.NewWithConfig(context.Background(), bootConfig)
	if err != nil {
		log.Fatalf("create pool: %v", err)
	}
	// Retry ping so we tolerate Postgres starting after Seedbank (e.g. after reboot).
	const dbRetries = 15
	const dbRetryInterval = 2 * time.Second
	var pingErr error
	for attempt := 1; attempt <= dbRetries; attempt++ {
		pingErr = bootPool.Ping(context.Background())
		if pingErr == nil {
			break
		}
		if attempt < dbRetries {
			log.Printf("ping database (attempt %d/%d): %v; retrying in %v", attempt, dbRetries, pingErr, dbRetryInterval)
			time.Sleep(dbRetryInterval)
		}
	}
	if pingErr != nil {
		bootPool.Close()
		log.Fatalf("ping database: %v", pingErr)
	}
	log.Println("database connected")

	entries, err := os.ReadDir("migrations")
	if err != nil {
		log.Printf("warning: could not read migrations dir: %v", err)
	} else {
		var names []string
		for _, e := range entries {
			if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
				names = append(names, e.Name())
			}
		}
		sort.Strings(names)
		for _, name := range names {
			path := filepath.Join("migrations", name)
			sql, err := os.ReadFile(path)
			if err != nil {
				bootPool.Close()
				log.Fatalf("read migration %s: %v", path, err)
			}
			if err := store.RunMigrations(context.Background(), bootPool, string(sql)); err != nil {
				bootPool.Close()
				log.Fatalf("migrate %s: %v", path, err)
			}
		}
		log.Println("migrations applied")
	}
	bootPool.Close()

	// Pool with pgvector types registered (required after extension exists).
	config, err := store.PoolConfig(databaseURL)
	if err != nil {
		log.Fatalf("parse database config: %v", err)
	}
	pool, err := pgxpool.NewWithConfig(context.Background(), config)
	if err != nil {
		log.Fatalf("create pool: %v", err)
	}
	defer pool.Close()
	if err := pool.Ping(context.Background()); err != nil {
		log.Fatalf("ping database (pgvector): %v", err)
	}

	s := store.NewStore(pool, dedupThreshold)
	mux := http.NewServeMux()
	mux.HandleFunc("POST /seeds", handler.HandleStoreSeed(s))
	mux.HandleFunc("POST /seeds/query", handler.HandleSeedsQuery(s))
	mux.HandleFunc("PATCH /seeds/{id}/metadata", handler.HandleUpdateSeedMetadata(s))
	mux.HandleFunc("POST /seeds/{id}/tags", handler.HandleUpdateSeedTags(s))
	mux.HandleFunc("GET /seeds/{id}", handler.HandleGetSeed(s))
	mux.HandleFunc("PUT /seeds/{id}", handler.HandleUpdateSeed(s))
	mux.HandleFunc("GET /search", handler.HandleSearch(s))
	mux.HandleFunc("GET /health", handler.HandleHealth(pool))
	mux.HandleFunc("POST /agent-contexts", handler.HandleCreateContext(s))
	mux.HandleFunc("GET /agent-contexts", handler.HandleListContexts(s))
	mux.HandleFunc("GET /agent-contexts/{id}", handler.HandleGetContext(s))
	mux.HandleFunc("GET /stats", handler.HandleStats(s))
	mux.Handle("/", http.FileServer(http.Dir("web")))

	corsHandler := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}

	logHandler := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			wrapped := &responseWriter{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(wrapped, r)
			log.Printf("%s %s %d %s", r.Method, r.URL.Path, wrapped.status, time.Since(start).Round(time.Millisecond))
		})
	}

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      corsHandler(logHandler(mux)),
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}
	go func() {
		log.Printf("listening on :%s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
	log.Println("bye")
}
