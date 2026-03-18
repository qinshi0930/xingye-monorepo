import { redis } from './index';
import { CACHE_TTL } from './config';
import { createChildLogger } from '@/lib/logger';

// 创建缓存模块的日志器
const logger = createChildLogger({ module: 'cache' });

/**
 * 从缓存获取数据
 * @param key 缓存键
 * @returns 缓存数据，不存在返回 null
 */
export async function get<T>(key: string): Promise<T | null> {
  try {
    const data = await redis.get(key);
    if (!data) return null;
    return JSON.parse(data) as T;
  } catch (error) {
    logger.error({ error, key }, 'Redis get error');
    return null;
  }
}

/**
 * 设置缓存数据
 * @param key 缓存键
 * @param value 缓存值
 * @param ttl 过期时间（秒），默认 10 分钟
 */
export async function set<T>(
  key: string,
  value: T,
  ttl: number = CACHE_TTL.DEFAULT
): Promise<void> {
  try {
    const serialized = JSON.stringify(value);
    await redis.setex(key, ttl, serialized);
  } catch (error) {
    logger.error({ error, key }, 'Redis set error');
  }
}

/**
 * 删除缓存
 * @param key 缓存键
 */
export async function del(key: string): Promise<void> {
  try {
    await redis.del(key);
  } catch (error) {
    logger.error({ error, key }, 'Redis del error');
  }
}

/**
 * 批量删除缓存（支持通配符模式）
 * @param pattern 匹配模式，如 "user:*"
 */
export async function clear(pattern: string): Promise<void> {
  try {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  } catch (error) {
    logger.error({ error, pattern }, 'Redis clear error');
  }
}

/**
 * 检查缓存是否存在
 * @param key 缓存键
 */
export async function exists(key: string): Promise<boolean> {
  try {
    const result = await redis.exists(key);
    return result === 1;
  } catch (error) {
    logger.error({ error, key }, 'Redis exists error');
    return false;
  }
}

/**
 * 获取缓存，不存在则执行工厂函数获取数据并缓存
 * @param key 缓存键
 * @param factory 数据获取工厂函数
 * @param ttl 过期时间（秒）
 * @returns 数据
 */
export async function getOrSet<T>(
  key: string,
  factory: () => Promise<T>,
  ttl: number = CACHE_TTL.DEFAULT
): Promise<T> {
  // 先尝试从缓存获取
  const cached = await get<T>(key);
  if (cached !== null) {
    return cached;
  }

  // 执行工厂函数获取数据
  const data = await factory();

  // 缓存数据（仅当数据不为 null/undefined 时）
  if (data !== null && data !== undefined) {
    await set(key, data, ttl);
  }

  return data;
}

/**
 * 更新缓存（仅当缓存存在时更新）
 * @param key 缓存键
 * @param value 新值
 * @param ttl 过期时间（秒）
 */
export async function update<T>(
  key: string,
  value: T,
  ttl: number = CACHE_TTL.DEFAULT
): Promise<void> {
  try {
    const exists = await redis.exists(key);
    if (exists) {
      await set(key, value, ttl);
    }
  } catch (error) {
    logger.error({ error, key }, 'Redis update error');
  }
}

/**
 * 设置缓存过期时间
 * @param key 缓存键
 * @param ttl 过期时间（秒）
 */
export async function expire(key: string, ttl: number): Promise<void> {
  try {
    await redis.expire(key, ttl);
  } catch (error) {
    logger.error({ error, key }, 'Redis expire error');
  }
}

/**
 * 获取缓存剩余过期时间
 * @param key 缓存键
 * @returns 剩余秒数，-1 表示永不过期，-2 表示不存在
 */
export async function ttl(key: string): Promise<number> {
  try {
    return await redis.ttl(key);
  } catch (error) {
    logger.error({ error, key }, 'Redis ttl error');
    return -2;
  }
}

/**
 * 批量获取缓存
 * @param keys 缓存键数组
 * @returns 数据数组
 */
export async function mget<T>(keys: string[]): Promise<(T | null)[]> {
  try {
    if (keys.length === 0) return [];
    const data = await redis.mget(...keys);
    return data.map((item) => (item ? (JSON.parse(item) as T) : null));
  } catch (error) {
    logger.error({ error, keys }, 'Redis mget error');
    return keys.map(() => null);
  }
}

/**
 * 批量设置缓存
 * @param entries 键值对数组
 * @param ttl 过期时间（秒）
 */
export async function mset<T>(
  entries: { key: string; value: T }[],
  ttl: number = CACHE_TTL.DEFAULT
): Promise<void> {
  try {
    if (entries.length === 0) return;

    const pipeline = redis.pipeline();

    for (const { key, value } of entries) {
      const serialized = JSON.stringify(value);
      pipeline.setex(key, ttl, serialized);
    }

    await pipeline.exec();
  } catch (error) {
    logger.error({ error, entryCount: entries.length }, 'Redis mset error');
  }
}
