import Redis from 'ioredis';
import { getRedisConfig, type RedisConfig } from './config';

export { getRedisConfig, type RedisConfig };

/**
 * 创建 Redis 客户端实例
 */
export function createRedisClient(config?: RedisConfig): Redis {
  const redisConfig = config || getRedisConfig();

  const client = new Redis({
    host: redisConfig.host,
    port: redisConfig.port,
    password: redisConfig.password,
    retryStrategy: redisConfig.retryStrategy,
    maxRetriesPerRequest: redisConfig.maxRetriesPerRequest,
    enableOfflineQueue: redisConfig.enableOfflineQueue,
    connectTimeout: redisConfig.connectTimeout,
    commandTimeout: redisConfig.commandTimeout,
  });

  return client;
}

export { Redis };
export default Redis;
