import { useState, useEffect, useCallback } from 'react';
import { Order, DownloadLink } from '../types';
import { useApi } from './useApi';

export function useOrders() {
  const { get, del, isReady } = useApi();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchOrders = useCallback(async () => {
    if (!isReady) return;
    setLoading(true);
    try {
      const data = await get<Order[]>('/api/orders');
      setOrders(data);
      setError(null);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, [get, isReady]);

  useEffect(() => {
    fetchOrders();
  }, [fetchOrders]);

  const deleteOrder = useCallback(
    async (id: number) => {
      await del(`/api/orders/${id}`);
      setOrders((prev) => prev.filter((o) => o.id !== id));
    },
    [del]
  );

  return { orders, loading, error, refetch: fetchOrders, deleteOrder };
}

export function useDownloadLinks(orderId: number | null) {
  const { get } = useApi();
  const [links, setLinks] = useState<DownloadLink[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!orderId) return;
    setLoading(true);
    get<DownloadLink[]>(`/api/orders/${orderId}/downloads`)
      .then(setLinks)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [orderId, get]);

  return { links, loading };
}
