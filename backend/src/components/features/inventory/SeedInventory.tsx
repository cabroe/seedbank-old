import React, { useState, useMemo } from 'react';
import { usePersistentState } from '../../../hooks/usePersistentState';
import type { SeedData } from '../../../types';
import { NeuronSearchBar } from './NeuronSearchBar';
import { NeuronTableRow } from './NeuronTableRow';
import { NeuronDetailPanel } from './NeuronDetailPanel';
import { NeuronEditModal } from './NeuronEditModal';


type SortKey = 'id' | 'content' | 'source' | 'tag' | 'score' | 'created_at';
type SortDir = 'asc' | 'desc';

interface SeedInventoryProps {
    seeds: SeedData[];
    totalCount?: number;
    onSearch?: (query: string) => void;
    onRefresh?: () => void;
}

const metaStr = (seed: SeedData, key: string): string => {
    const val = seed.metadata?.[key];
    return typeof val === 'string' ? val : '';
};

export const SeedInventory: React.FC<SeedInventoryProps> = ({ seeds, totalCount, onSearch, onRefresh }) => {
    const [sortKey, setSortKey] = usePersistentState<SortKey>('inventory_sort_key', 'id');
    const [sortDir, setSortDir] = usePersistentState<SortDir>('inventory_sort_dir', 'asc');
    const [query, setQuery] = usePersistentState('inventory_search_buffer', '');
    const [hoveredSeed, setHoveredSeed] = useState<SeedData | null>(null);
    const [mousePos, setMousePos] = useState({ x: 0, y: 0 });
    const [editingSeed, setEditingSeed] = useState<SeedData | null>(null);


    const handleSort = (key: SortKey) => {
        if (sortKey === key) {
            setSortDir(prev => prev === 'asc' ? 'desc' : 'asc');
        } else {
            setSortKey(key);
            setSortDir('asc');
        }
    };

    const handleSearch = (e: React.FormEvent) => {
        e.preventDefault();
        if (onSearch) onSearch(query || 'der');
    };

    const handleClear = () => {
        setQuery('');
        if (onSearch) onSearch('der');
    };

    const filteredAndSorted = useMemo(() => {
        const filtered = query
            ? seeds.filter(s => s.content.toLowerCase().includes(query.toLowerCase()))
            : seeds;

        return [...filtered].sort((a, b) => {
            let cmp = 0;
            switch (sortKey) {
                case 'id': cmp = a.id - b.id; break;
                case 'content': cmp = a.content.localeCompare(b.content); break;
                case 'source': cmp = metaStr(a, 'source').localeCompare(metaStr(b, 'source')); break;
                case 'tag': cmp = metaStr(a, 'tag').localeCompare(metaStr(b, 'tag')); break;
                case 'score': cmp = a.score - b.score; break;
                case 'created_at': cmp = a.created_at.localeCompare(b.created_at); break;
            }
            return sortDir === 'asc' ? cmp : -cmp;
        });
    }, [seeds, query, sortKey, sortDir]);

    const sortIndicator = (field: SortKey) =>
        sortKey === field ? (sortDir === 'asc' ? ' ▲' : ' ▼') : '';

    const thClass = "px-4 py-2 font-medium cursor-pointer select-none hover:text-white/50 transition-colors";

    return (
        <div className="glass-panel flex-1 flex flex-col min-h-0 overflow-hidden relative">
            <div className="p-4 border-b border-white/5 flex justify-between items-center gap-4">
                <h3 className="text-[11px] font-bold text-white/40 uppercase tracking-[0.2em] shrink-0">Neuron Matrix</h3>
                <NeuronSearchBar
                    query={query}
                    setQuery={setQuery}
                    onSubmit={handleSearch}
                    onClear={handleClear}
                />
                <div className="flex items-center gap-3 shrink-0">
                    <span className="text-[10px] text-primary/60 tabular-nums uppercase tracking-widest">
                        {query ? `${filteredAndSorted.length} / ` : ''}
                        Neurons: {totalCount ?? seeds.length}
                    </span>

                </div>
            </div>



            <div className="flex-1 overflow-y-auto">
                <table className="w-full text-left text-[11px] border-collapse">
                    <thead className="sticky top-0 bg-[#0a0f19] z-10 text-white/20 uppercase tracking-wider border-b border-white/5">
                        <tr>
                            <th className={thClass} onClick={() => handleSort('id')}>ID{sortIndicator('id')}</th>
                            <th className={thClass} onClick={() => handleSort('content')}>Content{sortIndicator('content')}</th>
                            <th className={thClass} onClick={() => handleSort('source')}>Source{sortIndicator('source')}</th>
                            <th className={thClass} onClick={() => handleSort('tag')}>Tag{sortIndicator('tag')}</th>
                            <th className={`${thClass} text-right`} onClick={() => handleSort('score')}>Score{sortIndicator('score')}</th>
                            <th className={thClass} onClick={() => handleSort('created_at')}>Created{sortIndicator('created_at')}</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-white/5">
                        {filteredAndSorted.map((seed) => (
                            <NeuronTableRow
                                key={seed.id}
                                seed={seed}
                                onHoverEnter={setHoveredSeed}
                                onHoverLeave={() => setHoveredSeed(null)}
                                onMouseMove={(e) => setMousePos({ x: e.clientX, y: e.clientY })}
                            />
                        ))}
                    </tbody>
                </table>
            </div>

            {hoveredSeed && (
                <NeuronDetailPanel seed={hoveredSeed} mousePos={mousePos} />
            )}

            {editingSeed && (
                <NeuronEditModal
                    seed={editingSeed}
                    onClose={() => setEditingSeed(null)}
                    onSaved={() => { setEditingSeed(null); onRefresh?.(); }}
                />
            )}
        </div>
    );
};
