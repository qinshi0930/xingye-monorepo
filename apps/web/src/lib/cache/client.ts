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

/**
 * 关闭 Redis 连接并清理全局引用
 * 用于测试环境和进程退出时确保资源正确释放
 */
export async function close(): Promise<void> {
  await redis.quit();
  // 清理全局引用，确保 Jest 可以正常退出
  if (globalThis.redis) {
    globalThis.redis = undefined;
  }
}

export default redis;
