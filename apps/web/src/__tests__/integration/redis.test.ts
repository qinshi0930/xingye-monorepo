import * as cache from '@/lib/cache';
import { close as closeRedis } from '@/lib/cache';
import { CACHE_TTL, buildCacheKey, buildListCacheKey } from '@/lib/cache';

describe('Redis Cache Operations', () => {
  const testKey = 'test:key';

  beforeEach(async () => {
    // 清理测试缓存
    await cache.clear('test:*');
  });

  afterAll(async () => {
    // 清理所有测试缓存
    await cache.clear('test:*');
    // 关闭Redis连接并清理全局引用，确保Jest能够正常退出
    await closeRedis();
  });

  describe('Basic Operations', () => {
    it('应该能够设置和获取缓存', async () => {
      const testData = { id: 1, name: 'Test User' };

      await cache.set(testKey, testData, 60);
      const result = await cache.get<typeof testData>(testKey);

      expect(result).toEqual(testData);
    });

    it('获取不存在的缓存应该返回 null', async () => {
      const result = await cache.get('test:nonexistent');
      expect(result).toBeNull();
    });

    it('应该能够删除缓存', async () => {
      const testData = { value: 'test' };
      await cache.set(testKey, testData, 60);

      await cache.del(testKey);
      const result = await cache.get(testKey);

      expect(result).toBeNull();
    });

    it('应该能够检查缓存是否存在', async () => {
      await cache.set(testKey, 'value', 60);

      const exists = await cache.exists(testKey);
      expect(exists).toBe(true);

      const notExists = await cache.exists('test:nonexistent');
      expect(notExists).toBe(false);
    });
  });

  describe('getOrSet Pattern', () => {
    it('应该优先返回缓存数据', async () => {
      const cachedData = { cached: true };
      await cache.set(testKey, cachedData, 60);

      const factory = jest.fn().mockResolvedValue({ cached: false });
      const result = await cache.getOrSet(testKey, factory, 60);

      expect(result).toEqual(cachedData);
      expect(factory).not.toHaveBeenCalled();
    });

    it('缓存不存在时应该执行工厂函数', async () => {
      const factoryData = { fromFactory: true };
      const factory = jest.fn().mockResolvedValue(factoryData);

      const result = await cache.getOrSet('test:newkey', factory, 60);

      expect(result).toEqual(factoryData);
      expect(factory).toHaveBeenCalledTimes(1);
    });

    it('工厂函数返回 null 时不应该缓存', async () => {
      const factory = jest.fn().mockResolvedValue(null);

      await cache.getOrSet('test:nullkey', factory, 60);
      const cached = await cache.get('test:nullkey');

      expect(cached).toBeNull();
    });
  });

  describe('Batch Operations', () => {
    it('应该支持批量获取', async () => {
      const data1 = { id: 1 };
      const data2 = { id: 2 };

      await cache.set('test:key1', data1, 60);
      await cache.set('test:key2', data2, 60);

      const results = await cache.mget(['test:key1', 'test:key2', 'test:key3']);

      expect(results[0]).toEqual(data1);
      expect(results[1]).toEqual(data2);
      expect(results[2]).toBeNull();
    });

    it('应该支持批量设置', async () => {
      const entries = [
        { key: 'test:batch1', value: { id: 1 } },
        { key: 'test:batch2', value: { id: 2 } },
      ];

      await cache.mset(entries, 60);

      const result1 = await cache.get('test:batch1');
      const result2 = await cache.get('test:batch2');

      expect(result1).toEqual({ id: 1 });
      expect(result2).toEqual({ id: 2 });
    });
  });

  describe('Clear Pattern', () => {
    it('应该能够按模式清除缓存', async () => {
      await cache.set('test:pattern:1', 'value1', 60);
      await cache.set('test:pattern:2', 'value2', 60);
      await cache.set('test:other', 'value3', 60);

      await cache.clear('test:pattern:*');

      const result1 = await cache.get('test:pattern:1');
      const result2 = await cache.get('test:pattern:2');
      const result3 = await cache.get('test:other');

      expect(result1).toBeNull();
      expect(result2).toBeNull();
      expect(result3).toBe('value3');
    });
  });

  describe('TTL Operations', () => {
    it('应该能够获取缓存剩余时间', async () => {
      await cache.set(testKey, 'value', 60);

      const ttl = await cache.ttl(testKey);

      expect(ttl).toBeGreaterThan(0);
      expect(ttl).toBeLessThanOrEqual(60);
    });

    it('应该能够更新缓存过期时间', async () => {
      await cache.set(testKey, 'value', 60);

      await cache.expire(testKey, 120);
      const ttl = await cache.ttl(testKey);

      expect(ttl).toBeGreaterThan(60);
    });
  });

  describe('Cache Key Building', () => {
    it('应该正确构建简单缓存键', () => {
      const key = buildCacheKey('user:id:', 123);
      expect(key).toBe('user:id:123');
    });

    it('应该正确构建列表缓存键', () => {
      const key = buildListCacheKey('posts:list:', {
        published: true,
        limit: 10,
        offset: 0,
      });

      expect(key).toContain('posts:list:');
      expect(key).toContain('limit:10');
      expect(key).toContain('offset:0');
      expect(key).toContain('published:true');
    });

    it('应该过滤 undefined 参数', () => {
      const key = buildListCacheKey('test:', {
        a: 1,
        b: undefined,
        c: 'value',
      });

      expect(key).toContain('a:1');
      expect(key).toContain('c:value');
      expect(key).not.toContain('b:');
    });
  });

  describe('Data Serialization', () => {
    it('应该正确处理复杂对象', async () => {
      const complexData = {
        id: 1,
        name: 'Test',
        nested: { value: 123 },
        array: [1, 2, 3],
        date: new Date('2024-01-01'),
      };

      await cache.set(testKey, complexData, 60);
      const result = await cache.get<typeof complexData>(testKey);

      // Date 对象会被 JSON 序列化为字符串
      expect(result).toEqual({
        ...complexData,
        date: '2024-01-01T00:00:00.000Z',
      });
    });

    it('应该正确处理数组', async () => {
      const arrayData = [
        { id: 1, name: 'Item 1' },
        { id: 2, name: 'Item 2' },
      ];

      await cache.set(testKey, arrayData, 60);
      const result = await cache.get<typeof arrayData>(testKey);

      expect(result).toEqual(arrayData);
      expect(Array.isArray(result)).toBe(true);
    });
  });
});

describe('Cache Configuration', () => {
  it('应该定义正确的 TTL 配置', () => {
    expect(CACHE_TTL.USER).toBe(3600); // 1小时
    expect(CACHE_TTL.POST).toBe(1800); // 30分钟
    expect(CACHE_TTL.POST_LIST).toBe(300); // 5分钟
    expect(CACHE_TTL.DEFAULT).toBe(600); // 10分钟
  });
});
