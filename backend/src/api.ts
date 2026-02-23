const API_BASE = 'http://localhost:9124';

// --- Types ---

export interface SearchResult {
    id: number;
    content: string;
    metadata: Record<string, unknown>;
    created_at: string;
    score: number;
}

export interface SeedsQueryResult {
    seedId: string;
    content: string;
    similarity: number;
}

export interface Stats {
    seedsCount: number;
    agentContextsCount: number;
}

export interface StoreSeedResponse {
    id: number;
    skipped?: number;
}

// --- Endpoints ---

/**
 * GET /search – Semantische Suche mit vollen Daten (metadata, created_at, score).
 * Beste Wahl für das Dashboard.
 */
export const searchSeeds = async (
    query: string,
    limit = 100,
    threshold = 0
): Promise<SearchResult[]> => {
    const params = new URLSearchParams({
        q: query,
        limit: String(limit),
        ...(threshold > 0 ? { threshold: String(threshold) } : {}),
    });
    const res = await fetch(`${API_BASE}/search?${params}`);
    if (!res.ok) throw new Error(`Search failed: ${res.status}`);
    return res.json();
};

/**
 * POST /seeds/query – Neutron-kompatible Suche (nur seedId, content, similarity).
 */
export const querySeeds = async (
    query: string,
    limit = 30,
    threshold = 0
): Promise<{ results: SeedsQueryResult[] }> => {
    const res = await fetch(`${API_BASE}/seeds/query`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, limit, threshold }),
    });
    if (!res.ok) throw new Error(`Query failed: ${res.status}`);
    return res.json();
};

/**
 * GET /stats – Dashboard-KPIs.
 */
export const fetchStats = async (): Promise<Stats> => {
    const res = await fetch(`${API_BASE}/stats`);
    if (!res.ok) throw new Error(`Stats failed: ${res.status}`);
    return res.json();
};

/**
 * GET /health – System-Status.
 */
export const fetchHealth = async (): Promise<boolean> => {
    try {
        const res = await fetch(`${API_BASE}/health`);
        return res.ok;
    } catch {
        return false;
    }
};

/**
 * POST /seeds – Neues Seed speichern.
 */
export const storeSeed = async (
    content: string,
    metadata: Record<string, unknown> = {}
): Promise<StoreSeedResponse> => {
    const res = await fetch(`${API_BASE}/seeds`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content, metadata }),
    });
    if (!res.ok) throw new Error(`Store failed: ${res.status}`);
    return res.json();
};

/**
 * GET /seeds/{id} – Einzelnes Seed abrufen.
 */
export const getSeed = async (id: number): Promise<SearchResult> => {
    const res = await fetch(`${API_BASE}/seeds/${id}`);
    if (!res.ok) throw new Error(`GetSeed failed: ${res.status}`);
    return res.json();
};

/**
 * PUT /seeds/{id} – Seed vollständig überschreiben.
 */
export const updateSeed = async (
    id: number,
    content: string,
    metadata: Record<string, unknown> = {}
): Promise<void> => {
    const res = await fetch(`${API_BASE}/seeds/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content, metadata }),
    });
    if (!res.ok) throw new Error(`UpdateSeed failed: ${res.status}`);
};

/**
 * PATCH /seeds/{id}/metadata – Metadata mergen.
 */
export const patchSeedMetadata = async (
    id: number,
    patch: Record<string, unknown>
): Promise<void> => {
    const res = await fetch(`${API_BASE}/seeds/${id}/metadata`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(patch),
    });
    if (!res.ok) throw new Error(`PatchMetadata failed: ${res.status}`);
};

/**
 * POST /seeds/{id}/tags – Tags setzen.
 */
export const updateSeedTags = async (
    id: number,
    tags: string[]
): Promise<void> => {
    const res = await fetch(`${API_BASE}/seeds/${id}/tags`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(tags),
    });
    if (!res.ok) throw new Error(`UpdateTags failed: ${res.status}`);
};

// --- Agent Contexts ---

export interface AgentContext {
    id: string;
    agentId: string;
    memoryType: 'episodic' | 'semantic' | 'procedural' | 'working';
    payload: Record<string, unknown>;
    createdAt: string;
}

/**
 * GET /agent-contexts – Alle Contexts abrufen (optional gefiltert).
 */
export const fetchContexts = async (
    agentId?: string,
    memoryType?: string
): Promise<AgentContext[]> => {
    const params = new URLSearchParams();
    if (agentId) params.set('agentId', agentId);
    if (memoryType) params.set('memoryType', memoryType);
    const qs = params.toString();
    const res = await fetch(`${API_BASE}/agent-contexts${qs ? '?' + qs : ''}`);
    if (!res.ok) throw new Error(`FetchContexts failed: ${res.status}`);
    return res.json();
};
