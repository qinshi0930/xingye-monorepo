// Redis 核心配置

export interface RedisConfig {
  host: string;
  port: number;
  password?: string;
  retryStrategy?: (times: number) => number;
  maxRetriesPerRequest?: number;
  enableOfflineQueue?: boolean;
  connectTimeout?: number;
  commandTimeout?: number;
}

/**
 * 获取 Redis 连接配置
 */
export function getRedisConfig(): RedisConfig {
  const host = process.env.REDIS_HOST || 'localhost';
  const port = parseInt(process.env.REDIS_PORT || '6379', 10);
  const password = process.env.REDIS_PASSWORD;

  return {
    host,
    port,
    password,
    // 连接重试策略
    retryStrategy: (times: number) => {
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
    // 最大重试次数
    maxRetriesPerRequest: 3,
    // 启用离线队列
    enableOfflineQueue: true,
    // 连接超时
    connectTimeout: 10000,
    // 命令超时
    commandTimeout: 5000,
  };
}
