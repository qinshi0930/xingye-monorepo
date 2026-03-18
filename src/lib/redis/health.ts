import { redis } from './index';
import { createChildLogger } from '@/lib/logger';

// 创建健康检查模块的日志器
const logger = createChildLogger({ module: 'redis-health' });

/**
 * Redis 健康状态
 */
export interface RedisHealthStatus {
  status: 'healthy' | 'unhealthy';
  connected: boolean;
  latency: number;
  error?: string;
}

/**
 * 检查 Redis 连接健康状态
 * @returns 健康状态信息
 */
export async function checkRedisHealth(): Promise<RedisHealthStatus> {
  const startTime = Date.now();

  try {
    // 尝试执行 PING 命令
    const result = await redis.ping();
    const latency = Date.now() - startTime;

    if (result === 'PONG') {
      return {
        status: 'healthy',
        connected: true,
        latency,
      };
    }

    return {
      status: 'unhealthy',
      connected: false,
      latency,
      error: 'Unexpected response from Redis',
    };
  } catch (error) {
    const latency = Date.now() - startTime;

    return {
      status: 'unhealthy',
      connected: false,
      latency,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * 等待 Redis 连接就绪
 * @param timeout 超时时间（毫秒），默认 5000
 * @returns 是否成功连接
 */
export async function waitForRedis(timeout = 5000): Promise<boolean> {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    const health = await checkRedisHealth();

    if (health.status === 'healthy') {
      return true;
    }

    // 等待 100ms 后重试
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  return false;
}

/**
 * 获取 Redis 连接信息（不包含敏感信息）
 */
export function getRedisInfo(): {
  host: string;
  port: number;
  status: string;
} {
  const options = redis.options;

  return {
    host: options.host || 'unknown',
    port: options.port || 0,
    status: redis.status,
  };
}

/**
 * 优雅关闭 Redis 连接
 */
export async function closeRedisConnection(): Promise<void> {
  try {
    await redis.quit();
    logger.info('Redis connection closed gracefully');
  } catch (error) {
    logger.error({ error }, 'Error closing Redis connection');
    // 强制断开
    redis.disconnect();
  }
}
