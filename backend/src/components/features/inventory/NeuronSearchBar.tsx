import React from 'react';
import { SearchBar } from '../../ui/SearchBar';

interface NeuronSearchBarProps {
    query: string;
    setQuery: (val: string) => void;
    onSubmit: (e: React.FormEvent) => void;
    onClear: () => void;
}

export const NeuronSearchBar: React.FC<NeuronSearchBarProps> = ({ query, setQuery, onSubmit, onClear }) => {
    return (
        <SearchBar
            value={query}
            onChange={setQuery}
            onSubmit={onSubmit}
            onClear={onClear}
            placeholder="Neural Search…"
        />
    );
};
