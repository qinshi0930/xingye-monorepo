// Web 应用缓存层统一导出

export { redis, close } from './client';
export {
  CACHE_TTL,
  CACHE_PREFIX,
  buildCacheKey,
  buildListCacheKey,
} from './config';
export {
  get,
  set,
  del,
  clear,
  exists,
  getOrSet,
  update,
  expire,
  ttl,
  mget,
  mset,
} from './operations';
