import { useState, useEffect, useCallback } from 'react';
import { SyncStatus } from '../types';
import { useApi } from './useApi';

export function useSyncStatus() {
  const { port } = useApi();
  const [status, setStatus] = useState<SyncStatus | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fetchStatus = useCallback(async () => {
    if (!port) return;
    try {
      const res = await fetch(`http://localhost:${port}/api/sync/status`);
      const data: SyncStatus = await res.json();
      setStatus(data);
      setError(null);
    } catch (e) {
      setError('バックエンドに接続できません');
    }
  }, [port]);

  useEffect(() => {
    fetchStatus();
    // 5秒ごとにステータスを更新
    const interval = setInterval(fetchStatus, 5000);
    return () => clearInterval(interval);
  }, [fetchStatus]);

  return { status, error, refetch: fetchStatus };
}
