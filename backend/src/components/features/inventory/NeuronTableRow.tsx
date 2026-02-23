import React from 'react';
import type { SeedData } from '../../../types';
import { formatDate } from '../../../utils/formatDate';

interface NeuronTableRowProps {
    seed: SeedData;
    onHoverEnter: (seed: SeedData) => void;
    onHoverLeave: () => void;
    onMouseMove: (e: React.MouseEvent) => void;
}

const metaStr = (seed: SeedData, key: string): string => {
    const val = seed.metadata?.[key];
    return typeof val === 'string' ? val : '';
};

export const NeuronTableRow: React.FC<NeuronTableRowProps> = ({ seed, onHoverEnter, onHoverLeave, onMouseMove }) => {
    const tags = Array.isArray(seed.metadata?.tags) ? (seed.metadata.tags as string[]) : [];

    return (
        <tr className="hover:bg-white/[0.02] transition-colors group cursor-default">

            <td className="px-4 py-2 text-white/40 tabular-nums">#{seed.id}</td>
            <td
                className="px-4 py-2 text-white/70 max-w-xs truncate group-hover:text-primary cursor-help"
                onMouseEnter={() => onHoverEnter(seed)}
                onMouseLeave={onHoverLeave}
                onMouseMove={onMouseMove}
            >
                {seed.content.length > 60 ? seed.content.substring(0, 60) + '…' : seed.content}
            </td>
            <td className="px-4 py-2 text-white/30 text-[10px]">{metaStr(seed, 'source') || '—'}</td>
            <td className="px-4 py-2 text-white/30 text-[10px]">
                <div className="flex items-center gap-1 flex-wrap">
                    {metaStr(seed, 'tag') && (
                        <span className="text-white/40">{metaStr(seed, 'tag')}</span>
                    )}
                    {tags.map((t, i) => (
                        <span key={i} className="px-1.5 py-0 rounded text-[8px] border border-primary/20 text-primary/60 bg-primary/5">
                            {t}
                        </span>
                    ))}
                    {!metaStr(seed, 'tag') && tags.length === 0 && '—'}
                </div>
            </td>
            <td className="px-4 py-2 text-right tabular-nums text-white/60">{(seed.score * 100).toFixed(1)}%</td>
            <td className="px-4 py-2 text-white/30 text-[10px] tabular-nums">{formatDate(seed.created_at)}</td>
        </tr>
    );
};
