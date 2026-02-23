import { useState, useEffect } from 'react';

/**
 * A custom hook that manages state and persists it to localStorage.
 * 
 * @param key The localStorage key to use
 * @param defaultValue The initial value if no value is found in localStorage
 */
export function usePersistentState<T>(key: string, defaultValue: T): [T, (val: T | ((prev: T) => T)) => void] {
    const [state, setState] = useState<T>(() => {
        try {
            const stored = localStorage.getItem(key);
            return stored ? JSON.parse(stored) : defaultValue;
        } catch (error) {
            console.error(`Error reading localStorage key "${key}":`, error);
            return defaultValue;
        }
    });

    useEffect(() => {
        try {
            localStorage.setItem(key, JSON.stringify(state));
        } catch (error) {
            console.error(`Error writing localStorage key "${key}":`, error);
        }
    }, [key, state]);

    return [state, setState];
}
