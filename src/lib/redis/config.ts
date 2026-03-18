// Redis 缓存配置

/**
 * 缓存 TTL 配置（单位：秒）
 */
export const CACHE_TTL = {
  // 用户数据缓存 1 小时
  USER: 60 * 60,
  // 文章数据缓存 30 分钟
  POST: 30 * 60,
  // 分类数据缓存 1 小时
  CATEGORY: 60 * 60,
  // 文章列表缓存 5 分钟
  POST_LIST: 5 * 60,
  // 默认缓存 10 分钟
  DEFAULT: 10 * 60,
} as const;

/**
 * 缓存键前缀配置
 */
export const CACHE_PREFIX = {
  USER: 'user:id:',
  USER_EMAIL: 'user:email:',
  USERNAME: 'user:username:',
  POST: 'post:id:',
  POST_SLUG: 'post:slug:',
  POSTS_LIST: 'posts:list:',
  POSTS_AUTHOR: 'posts:author:',
  CATEGORY: 'category:id:',
  CATEGORY_SLUG: 'category:slug:',
} as const;

/**
 * 获取 Redis 连接配置
 */
export function getRedisConfig() {
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

/**
 * 构建缓存键
 */
export function buildCacheKey(prefix: string, identifier: string | number): string {
  return `${prefix}${identifier}`;
}

/**
 * 构建列表缓存键
 */
export function buildListCacheKey(
  prefix: string,
  params: Record<string, string | number | boolean | undefined>
): string {
  const sortedParams = Object.entries(params)
    .filter(([, value]) => value !== undefined)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}:${value}`)
    .join(':');

  return `${prefix}${sortedParams}`;
}
