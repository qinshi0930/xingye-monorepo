import Redis from 'ioredis';
import { getRedisConfig } from './config';
import { createChildLogger } from '@/lib/logger';

// 创建 Redis 模块的日志器
const logger = createChildLogger({ module: 'redis' });

declare global {
  var redis: Redis | undefined;
}

/**
 * 创建 Redis 客户端实例
 */
function createRedisClient(): Redis {
  const config = getRedisConfig();

  const client = new Redis({
    host: config.host,
    port: config.port,
    password: config.password,
    retryStrategy: config.retryStrategy,
    maxRetriesPerRequest: config.maxRetriesPerRequest,
    enableOfflineQueue: config.enableOfflineQueue,
    connectTimeout: config.connectTimeout,
    commandTimeout: config.commandTimeout,
  });

  // 错误处理
  client.on('error', (err) => {
    logger.error({ err }, 'Redis Client Error');
  });

  client.on('connect', () => {
    logger.info('Redis Client Connected');
  });

  client.on('reconnecting', () => {
    logger.warn('Redis Client Reconnecting...');
  });

  client.on('close', () => {
    logger.info('Redis Client Connection Closed');
  });

  return client;
}

// 单例模式：防止开发环境下热重载创建多个连接
export const redis = globalThis.redis ?? createRedisClient();

if (process.env.NODE_ENV !== 'production') {
  globalThis.redis = redis;
}

export default redis;
