import React, { useRef, useLayoutEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import type { SeedData } from '../../../types';
import { formatDate } from '../../../utils/formatDate';

interface NeuronDetailPanelProps {
    seed: SeedData;
    mousePos: { x: number; y: number };
}

const metaStr = (seed: SeedData, key: string): string => {
    const val = seed.metadata?.[key];
    return typeof val === 'string' ? val : '';
};

export const NeuronDetailPanel: React.FC<NeuronDetailPanelProps> = ({ seed, mousePos }) => {
    const panelRef = useRef<HTMLDivElement>(null);
    const [panelHeight, setPanelHeight] = useState(0);

    useLayoutEffect(() => {
        if (panelRef.current) {
            setPanelHeight(panelRef.current.offsetHeight);
        }
    }, [seed]);

    // Collect all metadata keys for display
    const metaEntries = Object.entries(seed.metadata || {}).filter(
        ([, v]) => v !== null && v !== undefined && v !== ''
    );

    return createPortal(
        <div
            ref={panelRef}
            className="fixed z-[9999] pointer-events-none"
            style={{
                left: mousePos.x + 15,
                top: mousePos.y + 15 + panelHeight > window.innerHeight
                    ? mousePos.y - panelHeight - 15
                    : mousePos.y + 15,
            }}
        >
            <div className="bg-[#0a0f19]/90 backdrop-blur-xl border border-white/20 rounded-lg shadow-2xl p-4 w-80 flex flex-col gap-3 animate-in fade-in zoom-in duration-200">
                <div className="flex justify-between items-start">
                    <span className="text-[10px] font-bold text-primary/60 uppercase tracking-widest">Neuron Details</span>
                    <span className="text-[10px] text-white/20 tabular-nums">#{seed.id}</span>
                </div>

                <div className="text-[11px] text-white/90 leading-relaxed font-medium bg-white/5 p-2 rounded border border-white/5">
                    {seed.content}
                </div>

                <div className="grid grid-cols-2 gap-2">
                    <div className="bg-white/5 p-2 rounded border border-white/5">
                        <div className="text-[8px] text-white/30 uppercase tracking-tighter mb-1">Source</div>
                        <div className="text-[10px] text-white/60 truncate">{metaStr(seed, 'source') || '—'}</div>
                    </div>
                    <div className="bg-white/5 p-2 rounded border border-white/5">
                        <div className="text-[8px] text-white/30 uppercase tracking-tighter mb-1">Tag</div>
                        <div className="text-[10px] text-white/60 truncate">{metaStr(seed, 'tag') || '—'}</div>
                    </div>
                    <div className="bg-white/5 p-2 rounded border border-white/5">
                        <div className="text-[8px] text-white/30 uppercase tracking-tighter mb-1">Score</div>
                        <div className="text-[10px] text-white/60 tabular-nums">{(seed.score * 100).toFixed(1)}%</div>
                    </div>
                    <div className="bg-white/5 p-2 rounded border border-white/5">
                        <div className="text-[8px] text-white/30 uppercase tracking-tighter mb-1">Created</div>
                        <div className="text-[10px] text-white/60 tabular-nums">{formatDate(seed.created_at)}</div>
                    </div>
                </div>

                {/* Show all other metadata dynamically */}
                {metaEntries.length > 2 && (
                    <div className="bg-white/5 p-2 rounded border border-white/5">
                        <div className="text-[8px] text-white/30 uppercase tracking-tighter mb-1">Metadata</div>
                        <div className="space-y-0.5">
                            {metaEntries
                                .filter(([k]) => k !== 'source' && k !== 'tag')
                                .map(([k, v]) => (
                                    <div key={k} className="flex justify-between text-[9px]">
                                        <span className="text-white/30">{k}</span>
                                        <span className="text-white/50 truncate ml-2 max-w-[160px]">{String(v)}</span>
                                    </div>
                                ))}
                        </div>
                    </div>
                )}

                <div className="pt-2 border-t border-white/5 flex justify-between items-center text-[8px] text-white/20 uppercase tracking-[0.2em]">
                    <span>Neural Trace</span>
                    <span>{formatDate(seed.created_at)}</span>
                </div>
            </div>
        </div>,
        document.body
    );
};
