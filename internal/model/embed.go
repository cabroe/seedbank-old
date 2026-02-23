package model

import (
	"errors"
	"sync"

	"github.com/rcarmo/gte-go/gte"
)

var ErrModelNotLoaded = errors.New("embedding model not loaded")

var (
	model   *gte.Model
	modelMu sync.Mutex
)

// LoadModel loads the GTE-Small model from path. Safe to call once at startup.
func LoadModel(path string) (*gte.Model, error) {
	modelMu.Lock()
	defer modelMu.Unlock()
	if model != nil {
		return model, nil
	}
	m, err := gte.Load(path)
	if err != nil {
		return nil, err
	}
	model = m
	return model, nil
}

// Model returns the loaded model or nil. Call LoadModel first.
func Model() *gte.Model {
	modelMu.Lock()
	defer modelMu.Unlock()
	return model
}

// CloseModel closes the loaded model. Call at shutdown.
func CloseModel() {
	modelMu.Lock()
	defer modelMu.Unlock()
	if model != nil {
		model.Close()
		model = nil
	}
}

// Embed returns a 384-dim L2-normalized embedding for text.
func Embed(text string) ([]float32, error) {
	m := Model()
	if m == nil {
		return nil, ErrModelNotLoaded
	}
	return m.Embed(text)
}

// EmbedBatch returns embeddings for multiple texts (faster than repeated Embed).
func EmbedBatch(texts []string) ([][]float32, error) {
	m := Model()
	if m == nil {
		return nil, ErrModelNotLoaded
	}
	return m.EmbedBatch(texts)
}
