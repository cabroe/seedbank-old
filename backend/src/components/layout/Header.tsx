import React from 'react';
import type { Stats } from '../../api';

interface HeaderProps {
    healthy: boolean;
    stats: Stats;
}

export const Header: React.FC<HeaderProps> = ({ healthy, stats }) => {
    return (
        <header className="shrink-0 p-6 flex justify-between items-start border-b border-white/5 bg-white/[0.02]">
            <div>
                <h1 className="text-3xl font-black text-white tracking-tighter flex items-end gap-2 text-glow">
                    NEURAL <span className="text-primary text-xs tracking-[0.5em] mb-1.5 opacity-50">BRAIN_v4.2</span>
                </h1>
                <p className="text-[10px] text-white/40 mt-1 uppercase tracking-widest">Autonomous Intelligence Management Interface</p>
            </div>

            <div className="flex gap-12 text-right">
                <div>
                    <div className="text-[9px] text-white/20 uppercase tracking-widest mb-1">Status</div>
                    <div className={`text-lg font-bold tracking-tight ${healthy ? 'text-green-500/80' : 'text-red-500/80'}`}>
                        {healthy ? 'LIVE' : 'OFFLINE'}
                    </div>
                </div>
                <div>
                    <div className="text-[9px] text-white/20 uppercase tracking-widest mb-1">Total Neurons</div>
                    <div className="text-lg font-bold text-primary tracking-tight tabular-nums">{stats.seedsCount}</div>
                </div>
                <div>
                    <div className="text-[9px] text-white/20 uppercase tracking-widest mb-1">Synaptic Links</div>
                    <div className="text-lg font-bold text-secondary tracking-tight tabular-nums">{stats.agentContextsCount}</div>
                </div>
                <div>
                    <div className="text-[9px] text-white/20 uppercase tracking-widest mb-1">Clock</div>
                    <div className="text-lg font-bold text-white/60 tracking-tight tabular-nums">
                        {new Date().toLocaleTimeString()}
                    </div>
                </div>
            </div>
        </header>
    );
};
