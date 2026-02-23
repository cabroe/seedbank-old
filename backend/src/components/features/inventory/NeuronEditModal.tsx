import React, { useState } from 'react';
import type { SeedData } from '../../../types';
import { updateSeed, updateSeedTags } from '../../../api';
import { formatDate } from '../../../utils/formatDate';
import { Modal } from '../../ui/Modal';

interface NeuronEditModalProps {
    seed: SeedData;
    onClose: () => void;
    onSaved: () => void;
}

const metaStr = (seed: SeedData, key: string): string => {
    const val = seed.metadata?.[key];
    return typeof val === 'string' ? val : '';
};

export const NeuronEditModal: React.FC<NeuronEditModalProps> = ({ seed, onClose, onSaved }) => {
    const [content, setContent] = useState(seed.content);
    const [source, setSource] = useState(metaStr(seed, 'source'));
    const [tag, setTag] = useState(metaStr(seed, 'tag'));
    const [tagsInput, setTagsInput] = useState(
        Array.isArray(seed.metadata?.tags) ? (seed.metadata.tags as string[]).join(', ') : ''
    );
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');

    const handleSave = async () => {
        if (!content.trim()) return;
        setSaving(true);
        setError('');
        try {
            const metadata: Record<string, unknown> = { ...seed.metadata };
            if (source) metadata.source = source;
            if (tag) metadata.tag = tag;

            await updateSeed(seed.id, content, metadata);

            const newTags = tagsInput.split(',').map(t => t.trim()).filter(Boolean);
            if (newTags.length > 0) {
                await updateSeedTags(seed.id, newTags);
            }

            onSaved();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Save failed');
        } finally {
            setSaving(false);
        }
    };

    const inputClass = "w-full bg-white/5 border border-white/10 rounded px-3 py-1.5 text-[11px] text-white/90 placeholder-white/20 outline-none focus:border-primary/30 focus:bg-white/[0.05] transition-colors";
    const labelClass = "text-[9px] text-white/30 uppercase tracking-widest mb-1";

    return (
        <Modal title={`Edit Neuron #${seed.id}`} onClose={onClose}>
            <div>
                <div className={labelClass}>Content</div>
                <textarea
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    rows={5}
                    className={`${inputClass} resize-none`}
                />
            </div>

            <div className="grid grid-cols-2 gap-3">
                <div>
                    <div className={labelClass}>Source</div>
                    <input value={source} onChange={(e) => setSource(e.target.value)} placeholder="e.g. telegram" className={inputClass} />
                </div>
                <div>
                    <div className={labelClass}>Tag</div>
                    <input value={tag} onChange={(e) => setTag(e.target.value)} placeholder="e.g. Title" className={inputClass} />
                </div>
            </div>

            <div>
                <div className={labelClass}>Tags (comma-separated)</div>
                <input value={tagsInput} onChange={(e) => setTagsInput(e.target.value)} placeholder="e.g. important, personal, rule" className={inputClass} />
            </div>

            <div className="text-[9px] text-white/20 tabular-nums">
                Created: {formatDate(seed.created_at)} · Score: {(seed.score * 100).toFixed(1)}%
            </div>

            {error && (
                <div className="text-[10px] text-red-400 bg-red-400/10 border border-red-500/20 rounded px-3 py-1.5">{error}</div>
            )}

            <div className="flex justify-end gap-2 pt-2 border-t border-white/5">
                <button
                    onClick={onClose}
                    className="text-[10px] text-white/30 hover:text-white/60 px-4 py-1.5 rounded border border-white/10 hover:border-white/20 transition-colors"
                >
                    Cancel
                </button>
                <button
                    onClick={handleSave}
                    disabled={saving || !content.trim()}
                    className="text-[10px] text-primary px-4 py-1.5 rounded border border-primary/30 bg-primary/10 hover:bg-primary/20 transition-colors disabled:opacity-30"
                >
                    {saving ? 'Saving…' : 'Save'}
                </button>
            </div>
        </Modal>
    );
};
