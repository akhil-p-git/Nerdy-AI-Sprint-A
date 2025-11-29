import { useEffect, useRef, useCallback } from 'react';
import { wsManager } from '../lib/websocket';

interface UseWebSocketOptions {
  channel: string;
  params: Record<string, any>;
  onMessage: (data: any) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
  enabled?: boolean;
}

export function useWebSocket({
  channel,
  params,
  onMessage,
  onConnect,
  onDisconnect,
  enabled = true
}: UseWebSocketOptions) {
  const unsubscribeRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    if (!enabled) return;

    unsubscribeRef.current = wsManager.subscribe(channel, params, {
      onMessage,
      onConnect,
      onDisconnect
    });

    return () => {
      unsubscribeRef.current?.();
    };
  }, [channel, JSON.stringify(params), enabled]);

  const perform = useCallback((action: string, data: any) => {
    wsManager.perform(channel, params, action, data);
  }, [channel, JSON.stringify(params)]);

  return { perform };
}


