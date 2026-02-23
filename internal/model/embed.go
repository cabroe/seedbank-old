package model

import (
	"errors"
	"sync"
	"container/list"

	"github.com/rcarmo/gte-go/gte"
)

var ErrModelNotLoaded = errors.New("embedding model not loaded")

const cacheSize = 256

type entry struct {
	key   string
	value []float32
}

var (
	model     *gte.Model
	modelMu   sync.Mutex
	cache     = make(map[string]*list.Element)
	evictList = list.New()
	cacheMu   sync.Mutex
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
	cacheMu.Lock()
	defer cacheMu.Unlock()
	cache = make(map[string]*list.Element)
	evictList.Init()
}

// Embed returns a 384-dim L2-normalized embedding for text (cached).
func Embed(text string) ([]float32, error) {
	cacheMu.Lock()
	if ent, ok := cache[text]; ok {
		evictList.MoveToFront(ent)
		res := ent.Value.(*entry).value
		cacheMu.Unlock()
		return res, nil
	}
	cacheMu.Unlock()

	m := Model()
	if m == nil {
		return nil, ErrModelNotLoaded
	}
	emb, err := m.Embed(text)
	if err != nil {
		return nil, err
	}

	// Update cache
	cacheMu.Lock()
	defer cacheMu.Unlock()
	if ent, ok := cache[text]; ok {
		evictList.MoveToFront(ent)
		return emb, nil
	}
	e := &entry{text, emb}
	ent := evictList.PushFront(e)
	cache[text] = ent
	if evictList.Len() > cacheSize {
		oldest := evictList.Back()
		if oldest != nil {
			evictList.Remove(oldest)
			kv := oldest.Value.(*entry)
			delete(cache, kv.key)
		}
	}

	return emb, nil
}

// EmbedBatch returns embeddings for multiple texts (not cached).
func EmbedBatch(texts []string) ([][]float32, error) {
	m := Model()
	if m == nil {
		return nil, ErrModelNotLoaded
	}
	return m.EmbedBatch(texts)
}
