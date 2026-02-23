import React from 'react';

export const Footer: React.FC = () => {
    return (
        <footer className="shrink-0 h-6 bg-black/40 border-t border-white/5 px-4 flex items-center justify-between text-[9px] text-white/30 uppercase tracking-[0.2em]">
            <div className="flex gap-4">
                <span>SECURE_CONNECTION: ESTABLISHED</span>
                <span>API: localhost:9124</span>
            </div>
            <div className="flex gap-4">
                <span className="text-primary">DATA_SOURCE: GET /search + GET /stats</span>
                <span>© 2026 SEEDBANK SYSTEMS</span>
            </div>
        </footer>
    );
};
