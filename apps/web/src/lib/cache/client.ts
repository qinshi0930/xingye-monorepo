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
 * 
 * @param force - 是否强制关闭。默认 false 使用 quit() 优雅关闭，
 *                true 使用 disconnect() 强制关闭（测试环境推荐）
 */
export async function close(force: boolean = false): Promise<void> {
  // 如果连接已经关闭，直接清理引用
  if (redis.status === 'end' || redis.status === 'close') {
    if (globalThis.redis) {
      globalThis.redis = undefined;
    }
    return;
  }

  // 使用 Promise 等待连接真正关闭
  await new Promise<void>((resolve) => {
    // 设置超时，避免永久等待
    const timeout = setTimeout(() => {
      redis.removeListener('end', onEnd);
      resolve();
    }, 1000);

    // 监听 end 事件，确保连接真正关闭
    const onEnd = () => {
      clearTimeout(timeout);
      resolve();
    };
    
    redis.once('end', onEnd);

    // 执行关闭命令
    if (force) {
      redis.disconnect();
    } else {
      redis.quit().catch(() => {
        // quit() 可能因连接已关闭而失败，忽略错误
        onEnd();
      });
    }
  });
  
  if (globalThis.redis) {
    globalThis.redis = undefined;
  }
}

export default redis;
