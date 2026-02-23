import React from 'react';

interface ModalProps {
    title: string;
    onClose: () => void;
    children: React.ReactNode;
    width?: string;
}

export const Modal: React.FC<ModalProps> = ({ title, onClose, children, width = '500px' }) => {
    return (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center" onClick={onClose}>
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
            <div
                className="relative bg-[#0a0f19] border border-white/15 rounded-xl shadow-2xl max-h-[80vh] overflow-y-auto p-6 flex flex-col gap-4 animate-in fade-in zoom-in duration-200"
                style={{ width }}
                onClick={(e) => e.stopPropagation()}
            >
                <div className="flex justify-between items-center">
                    <h2 className="text-[12px] font-bold text-white/60 uppercase tracking-[0.2em]">
                        {title}
                    </h2>
                    <button onClick={onClose} className="text-white/20 hover:text-white/60 text-lg transition-colors">✕</button>
                </div>
                {children}
            </div>
        </div>
    );
};
