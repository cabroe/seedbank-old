import React, { useState, useEffect } from 'react';
import type { SeedData } from '../../types';
import { searchSeeds, fetchStats, fetchHealth } from '../../api';
import type { Stats } from '../../api';
import { usePersistentState } from '../../hooks/usePersistentState';
import { Header } from './Header';
import { SeedInventory } from '../features/inventory/SeedInventory';
import { ActivityWall } from '../features/activity/ActivityWall';
import { Footer } from './Footer';

export const Dashboard: React.FC = () => {
    const [seeds, setSeeds] = useState<SeedData[]>([]);
    const [stats, setStats] = useState<Stats>({ seedsCount: 0, agentContextsCount: 0 });
    const [healthy, setHealthy] = useState(true);
    const [searchQuery, setSearchQuery] = usePersistentState('dashboard_query', 'der');

    const refresh = async () => {
        try {
            const [results, statsData, isHealthy] = await Promise.all([
                searchSeeds(searchQuery, 100, 0),
                fetchStats(),
                fetchHealth(),
            ]);

            setSeeds(results);
            setStats(statsData);
            setHealthy(isHealthy);
        } catch (error) {
            console.error('API refresh failed:', error);
            setHealthy(false);
        }
    };

    useEffect(() => {
        const init = async () => { await refresh(); };
        init();
        const interval = setInterval(refresh, 5000);
        return () => clearInterval(interval);
    }, [searchQuery]);

    return (
        <div className="flex flex-col h-[calc(100vh-1rem)] bg-background overflow-hidden border border-white/5 m-2 rounded-xl border-glow">
            <Header healthy={healthy} stats={stats} />

            <main className="flex-1 flex gap-4 p-4 min-h-0">
                <SeedInventory
                    seeds={seeds}
                    totalCount={stats.seedsCount}
                    onSearch={(q: string) => { setSearchQuery(q); }}
                    onRefresh={refresh}
                />
                <ActivityWall />
            </main>

            <Footer />
        </div>
    );
};
