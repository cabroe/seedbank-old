import React, { useState, useEffect } from 'react';
import type { AgentContext } from '../../../api';
import { fetchContexts } from '../../../api';
import { formatDate } from '../../../utils/formatDate';

const MEMORY_TYPE_COLORS: Record<string, string> = {
    episodic: 'bg-blue-500',
    semantic: 'bg-emerald-500',
    procedural: 'bg-amber-500',
    working: 'bg-purple-500',
};

const MEMORY_TYPE_LABELS: Record<string, string> = {
    episodic: 'EPISODIC',
    semantic: 'SEMANTIC',
    procedural: 'PROCEDURAL',
    working: 'WORKING',
};

export const ActivityWall: React.FC = () => {
    const [contexts, setContexts] = useState<AgentContext[]>([]);
    const [filter, setFilter] = useState<string>('');
    const [loading, setLoading] = useState(true);

    const load = async () => {
        try {
            const data = await fetchContexts(undefined, filter || undefined);
            setContexts(data);
        } catch (err) {
            console.error('Failed to fetch contexts:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        load();
        const interval = setInterval(load, 8000);
        return () => clearInterval(interval);
    }, [filter]);

    const payloadSummary = (payload: Record<string, unknown>): string => {
        const keys = Object.keys(payload);
        if (keys.length === 0) return '{}';
        // Try to find a useful text field
        for (const key of ['content', 'text', 'message', 'summary', 'input']) {
            if (typeof payload[key] === 'string') {
                const s = payload[key] as string;
                return s.length > 80 ? s.substring(0, 80) + '…' : s;
            }
        }
        return `{${keys.slice(0, 3).join(', ')}${keys.length > 3 ? ', …' : ''}}`;
    };

    const memoryTypes = ['', 'episodic', 'semantic', 'procedural', 'working'];

    return (
        <div className="glass-panel w-80 flex flex-col min-h-0 overflow-hidden">
            <div className="p-4 border-b border-white/5">
                <h3 className="text-[11px] font-bold text-white/40 uppercase tracking-[0.2em] flex items-center gap-2 mb-3">
                    <span className="w-2 h-2 bg-primary rounded-full pulse-glow" />
                    Synaptic Stream
                </h3>
                {/* Memory Type Filter */}
                <div className="flex gap-1 flex-wrap">
                    {memoryTypes.map((mt) => (
                        <button
                            key={mt || 'all'}
                            onClick={() => setFilter(mt)}
                            className={`text-[8px] uppercase tracking-wider px-2 py-0.5 rounded-full border transition-all duration-200 ${filter === mt
                                ? 'border-primary/50 text-primary bg-primary/10'
                                : 'border-white/10 text-white/30 hover:text-white/50 hover:border-white/20'
                                }`}
                        >
                            {mt || 'All'}
                        </button>
                    ))}
                </div>
            </div>
            <div className="flex-1 overflow-y-auto p-4 space-y-3">
                {loading && contexts.length === 0 && (
                    <div className="text-[10px] text-white/20 text-center py-4">Loading…</div>
                )}
                {!loading && contexts.length === 0 && (
                    <div className="text-[10px] text-white/20 text-center py-4">No contexts found</div>
                )}
                {contexts.map((ctx) => (
                    <div key={ctx.id} className="relative pl-4 border-l border-white/10 group hover:border-white/20 transition-colors">
                        <div className={`absolute -left-[5px] top-1.5 w-2 h-2 rounded-full ${MEMORY_TYPE_COLORS[ctx.memoryType] || 'bg-white/30'}`} />
                        <div className="flex items-center gap-2 mb-1">
                            <span className={`text-[8px] uppercase tracking-wider px-1.5 py-0.5 rounded border ${ctx.memoryType === 'episodic' ? 'border-blue-500/30 text-blue-400' :
                                ctx.memoryType === 'semantic' ? 'border-emerald-500/30 text-emerald-400' :
                                    ctx.memoryType === 'procedural' ? 'border-amber-500/30 text-amber-400' :
                                        'border-purple-500/30 text-purple-400'
                                }`}>
                                {MEMORY_TYPE_LABELS[ctx.memoryType] || ctx.memoryType}
                            </span>
                            <span className="text-[9px] text-white/20 tabular-nums">
                                {formatDate(ctx.createdAt)}
                            </span>
                        </div>
                        <div className="text-[10px] text-white/30 mb-0.5 truncate">
                            Agent: {ctx.agentId}
                        </div>
                        <div className="text-[11px] text-white/60 leading-relaxed">
                            {payloadSummary(ctx.payload)}
                        </div>
                    </div>
                ))}
            </div>
            <div className="p-3 border-t border-white/5 text-[9px] text-white/20 text-center tabular-nums">
                {contexts.length} Context{contexts.length !== 1 ? 's' : ''}
            </div>
        </div>
    );
};
