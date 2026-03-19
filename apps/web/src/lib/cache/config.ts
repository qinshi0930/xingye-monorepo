// Web 应用的缓存配置

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
 * 使用 web: 前缀避免与其他应用冲突
 */
export const CACHE_PREFIX = {
  USER: 'web:user:id:',
  USER_EMAIL: 'web:user:email:',
  USERNAME: 'web:user:username:',
  POST: 'web:post:id:',
  POST_SLUG: 'web:post:slug:',
  POSTS_LIST: 'web:posts:list:',
  POSTS_AUTHOR: 'web:posts:author:',
  CATEGORY: 'web:category:id:',
  CATEGORY_SLUG: 'web:category:slug:',
} as const;

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
