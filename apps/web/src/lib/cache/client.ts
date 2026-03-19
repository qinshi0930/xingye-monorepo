import { createRedisClient } from '@xingye/redis-core';
import { createChildLogger } from '@xingye/logger';

// 创建缓存模块的日志器
const logger = createChildLogger({ module: 'cache' });

declare global {
  var redis: ReturnType<typeof createRedisClient> | undefined;
}

/**
 * 创建带日志的 Redis 客户端
 */
function createCacheClient() {
  const client = createRedisClient();

  // 错误处理
  client.on('error', (err: Error) => {
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
export const redis = globalThis.redis ?? createCacheClient();

if (process.env.NODE_ENV !== 'production') {
  globalThis.redis = redis;
}

export default redis;
