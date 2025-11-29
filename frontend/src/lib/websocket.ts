type MessageHandler = (data: any) => void;
type ConnectionHandler = () => void;

interface Subscription {
  channel: string;
  params: Record<string, any>;
  handlers: {
    onMessage: MessageHandler;
    onConnect?: ConnectionHandler;
    onDisconnect?: ConnectionHandler;
  };
}

class WebSocketManager {
  private ws: WebSocket | null = null;
  private url: string;
  private subscriptions: Map<string, Subscription> = new Map();
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000;
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private isConnecting = false;

  constructor() {
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const baseUrl = import.meta.env.VITE_WS_URL || `${wsProtocol}//${window.location.host}`;
    this.url = `${baseUrl}/cable`;
  }

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        resolve();
        return;
      }

      if (this.isConnecting) {
        // Wait for existing connection attempt
        const checkConnection = setInterval(() => {
          if (this.ws?.readyState === WebSocket.OPEN) {
            clearInterval(checkConnection);
            resolve();
          }
        }, 100);
        return;
      }

      this.isConnecting = true;
      const token = localStorage.getItem('token');

      this.ws = new WebSocket(`${this.url}?token=${token}`);

      this.ws.onopen = () => {
        console.log('WebSocket connected');
        this.isConnecting = false;
        this.reconnectAttempts = 0;
        this.startHeartbeat();

        // Resubscribe to all channels
        this.subscriptions.forEach((sub) => {
          this.sendSubscribe(sub.channel, sub.params);
          sub.handlers.onConnect?.();
        });

        resolve();
      };

      this.ws.onmessage = (event) => {
        const data = JSON.parse(event.data);

        if (data.type === 'ping') {
          this.send({ type: 'pong' });
          return;
        }

        if (data.type === 'confirm_subscription') {
          console.log('Subscription confirmed:', data.identifier);
          return;
        }

        if (data.identifier && data.message) {
          const subscription = this.subscriptions.get(data.identifier);
          subscription?.handlers.onMessage(data.message);
        }
      };

      this.ws.onclose = () => {
        console.log('WebSocket disconnected');
        this.isConnecting = false;
        this.stopHeartbeat();

        this.subscriptions.forEach(sub => {
          sub.handlers.onDisconnect?.();
        });

        this.attemptReconnect();
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        this.isConnecting = false;
        reject(error);
      };
    });
  }

  private attemptReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

    console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

    setTimeout(() => {
      this.connect();
    }, delay);
  }

  private startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.send({ type: 'ping' });
      }
    }, 30000);
  }

  private stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  private send(data: any) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    }
  }

  private sendSubscribe(channel: string, params: Record<string, any>) {
    const identifier = JSON.stringify({ channel, ...params });
    this.send({
      command: 'subscribe',
      identifier
    });
  }

  subscribe(
    channel: string,
    params: Record<string, any>,
    handlers: Subscription['handlers']
  ): () => void {
    const identifier = JSON.stringify({ channel, ...params });

    this.subscriptions.set(identifier, { channel, params, handlers });

    if (this.ws?.readyState === WebSocket.OPEN) {
      this.sendSubscribe(channel, params);
    } else {
      this.connect();
    }

    // Return unsubscribe function
    return () => {
      this.subscriptions.delete(identifier);
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.send({
          command: 'unsubscribe',
          identifier
        });
      }
    };
  }

  perform(channel: string, params: Record<string, any>, action: string, data: any) {
    const identifier = JSON.stringify({ channel, ...params });

    this.send({
      command: 'message',
      identifier,
      data: JSON.stringify({ action, ...data })
    });
  }

  disconnect() {
    this.stopHeartbeat();
    this.subscriptions.clear();
    this.ws?.close();
    this.ws = null;
  }
}

export const wsManager = new WebSocketManager();


