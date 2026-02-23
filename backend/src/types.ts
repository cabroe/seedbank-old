import type { SearchResult } from './api';

/**
 * SeedData is a direct alias for the API SearchResult.
 * Only real server data – no invented fields.
 */
export type SeedData = SearchResult;

/** Helper to extract a string from seed metadata. */
export const metaString = (seed: SeedData, key: string): string => {
    const val = seed.metadata?.[key];
    return typeof val === 'string' ? val : '';
};
