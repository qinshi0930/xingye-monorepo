import * as cache from './cache';
import { CACHE_TTL } from './config';

/**
 * 缓存选项
 */
export interface CacheOptions<T> {
  /** 缓存键或键生成函数 */
  key: string | ((...args: unknown[]) => string);
  /** 过期时间（秒） */
  ttl?: number;
  /** 缓存条件：返回 true 才缓存 */
  condition?: (result: T) => boolean;
  /** 是否跳过缓存 */
  skipCache?: boolean;
}

/**
 * 为异步函数添加缓存能力
 * @param fn 原始函数
 * @param options 缓存选项
 * @returns 带缓存的函数
 */
export function withCache<T, Args extends unknown[]>(
  fn: (...args: Args) => Promise<T>,
  options: CacheOptions<T>
): (...args: Args) => Promise<T> {
  const { key, ttl = CACHE_TTL.DEFAULT, condition, skipCache } = options;

  return async (...args: Args): Promise<T> => {
    // 如果跳过缓存，直接执行原函数
    if (skipCache) {
      return fn(...args);
    }

    // 生成缓存键
    const cacheKey = typeof key === 'function' ? key(...args) : key;

    // 尝试从缓存获取
    const cached = await cache.get<T>(cacheKey);
    if (cached !== null) {
      return cached;
    }

    // 执行原函数
    const result = await fn(...args);

    // 检查缓存条件
    if (condition && !condition(result)) {
      return result;
    }

    // 写入缓存
    if (result !== null && result !== undefined) {
      await cache.set(cacheKey, result, ttl);
    }

    return result;
  };
}

/**
 * 为类方法添加缓存装饰器
 * 注意：此装饰器需要配合 experimentalDecorators 使用
 */
export function Cacheable<T>(options: CacheOptions<T>) {
  return function (
    target: unknown,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;
    const { key, ttl = CACHE_TTL.DEFAULT, condition } = options;

    descriptor.value = async function (...args: unknown[]) {
      // 生成缓存键
      const cacheKey =
        typeof key === 'function'
          ? key(...args)
          : `${key}:${args.join(':')}`;

      // 尝试从缓存获取
      const cached = await cache.get<T>(cacheKey);
      if (cached !== null) {
        return cached;
      }

      // 执行原方法
      const result = await originalMethod.apply(this, args);

      // 检查缓存条件
      if (condition && !condition(result)) {
        return result;
      }

      // 写入缓存
      if (result !== null && result !== undefined) {
        await cache.set(cacheKey, result, ttl);
      }

      return result;
    };

    return descriptor;
  };
}

/**
 * 缓存失效装饰器
 * 在执行方法后清除指定模式的缓存
 */
export function CacheEvict(pattern: string | ((...args: unknown[]) => string)) {
  return function (
    target: unknown,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: unknown[]) {
      // 执行原方法
      const result = await originalMethod.apply(this, args);

      // 清除缓存
      const cachePattern =
        typeof pattern === 'function' ? pattern(...args) : pattern;
      await cache.clear(cachePattern);

      return result;
    };

    return descriptor;
  };
}

/**
 * 创建带缓存的服务包装器
 * 适用于对整个服务类的方法批量添加缓存
 */
export function createCachedService<T extends Record<string, unknown>>(
  service: T,
  cacheConfig: Partial<{
    [K in keyof T]: T[K] extends (...args: unknown[]) => Promise<infer R>
      ? CacheOptions<R>
      : never;
  }>
): T {
  const cachedService = { ...service };

  for (const [key, config] of Object.entries(cacheConfig)) {
    const method = service[key as keyof T];
    if (typeof method === 'function' && config) {
      (cachedService as Record<string, unknown>)[key] = withCache(
        method.bind(service) as (...args: unknown[]) => Promise<unknown>,
        config as CacheOptions<unknown>
      );
    }
  }

  return cachedService;
}

/**
 * 手动清除函数相关的缓存
 * @param key 缓存键或键生成函数
 * @param args 生成缓存键的参数
 */
export async function invalidateCache(
  key: string | ((...args: unknown[]) => string),
  ...args: unknown[]
): Promise<void> {
  const cacheKey = typeof key === 'function' ? key(...args) : key;
  await cache.del(cacheKey);
}

/**
 * 批量清除缓存
 * @param patterns 缓存键模式数组
 */
export async function invalidateCaches(...patterns: string[]): Promise<void> {
  for (const pattern of patterns) {
    await cache.clear(pattern);
  }
}
