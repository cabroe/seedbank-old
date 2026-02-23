/**
 * Formats an ISO timestamp into a compact German-locale date string.
 */
export const formatDate = (ts: string): string => {
    if (!ts) return '—';
    return new Date(ts).toLocaleDateString('de-DE', {
        day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit'
    });
};
