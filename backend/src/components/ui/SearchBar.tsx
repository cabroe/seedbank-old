import React from 'react';

interface SearchBarProps {
    value: string;
    onChange: (val: string) => void;
    onSubmit: (e: React.FormEvent) => void;
    onClear: () => void;
    placeholder?: string;
    className?: string;
}

export const SearchBar: React.FC<SearchBarProps> = ({ value, onChange, onSubmit, onClear, placeholder = 'Search…', className = '' }) => {
    return (
        <form onSubmit={onSubmit} className={`flex-1 max-w-xs relative group/search ${className}`}>
            <div className="absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none z-10">
                <svg className="w-3.5 h-3.5 text-white/10 group-focus-within/search:text-primary/60 transition-colors duration-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
            </div>
            <input
                type="text"
                value={value}
                onChange={(e) => onChange(e.target.value)}
                placeholder={placeholder}
                className="w-full h-8 bg-white/[0.02] border border-white/10 rounded-lg pl-9 pr-8 text-[11px] leading-none text-white/90 placeholder-white/20 outline-none focus:border-primary/30 focus:bg-white/[0.05] focus:ring-1 focus:ring-primary/10 transition-all duration-300 shadow-inner group-hover/search:border-white/20"
            />
            {value && (
                <button
                    type="button"
                    onClick={onClear}
                    className="absolute right-2.5 top-1/2 -translate-y-1/2 text-white/10 hover:text-white/60 text-[11px] leading-none transition-colors duration-200 p-1"
                >
                    ✕
                </button>
            )}
        </form>
    );
};
