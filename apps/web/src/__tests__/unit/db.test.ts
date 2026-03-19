import { getDatabaseUrl } from '@/lib/db/index';

describe('Drizzle DB Configuration', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    // 重置环境变量
    process.env = { ...originalEnv };
    delete process.env.DATABASE_URL;
    delete process.env.POSTGRES_HOST;
    delete process.env.POSTGRES_PORT;
    delete process.env.POSTGRES_USER;
    delete process.env.POSTGRES_PASSWORD;
    delete process.env.POSTGRES_DB;
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  describe('getDatabaseUrl()', () => {
    it('应该优先使用完整的 DATABASE_URL 环境变量', () => {
      process.env.DATABASE_URL = 'postgresql://user:pass@custom-host:5433/customdb?sslmode=require';
      
      const url = getDatabaseUrl();
      
      expect(url).toBe('postgresql://user:pass@custom-host:5433/customdb?sslmode=require');
    });

    it('当 DATABASE_URL 为空字符串时应该使用分散的环境变量', () => {
      process.env.DATABASE_URL = '';
      process.env.POSTGRES_HOST = 'my-host';
      process.env.POSTGRES_PORT = '5433';
      process.env.POSTGRES_USER = 'myuser';
      process.env.POSTGRES_PASSWORD = 'mypass';
      process.env.POSTGRES_DB = 'mydb';
      
      const url = getDatabaseUrl();
      
      expect(url).toBe('postgresql://myuser:mypass@my-host:5433/mydb?sslmode=disable');
    });

    it('当 DATABASE_URL 只有空格时应该使用分散的环境变量', () => {
      process.env.DATABASE_URL = '   ';
      process.env.POSTGRES_HOST = 'my-host';
      process.env.POSTGRES_USER = 'myuser';
      process.env.POSTGRES_DB = 'mydb';
      
      const url = getDatabaseUrl();
      
      expect(url).toBe('postgresql://myuser@my-host:5432/mydb?sslmode=disable');
    });

    it('应该使用默认值当没有环境变量时', () => {
      const url = getDatabaseUrl();
      
      expect(url).toBe('postgresql://postgres@localhost:5432/mydb?sslmode=disable');
    });

    it('应该正确处理没有密码的情况', () => {
      process.env.POSTGRES_USER = 'admin';
      process.env.POSTGRES_HOST = 'db.example.com';
      process.env.POSTGRES_DB = 'appdb';
      
      const url = getDatabaseUrl();
      
      expect(url).toBe('postgresql://admin@db.example.com:5432/appdb?sslmode=disable');
    });

    it('应该正确构建所有自定义环境变量的连接字符串', () => {
      process.env.POSTGRES_HOST = 'prod-db.internal';
      process.env.POSTGRES_PORT = '5433';
      process.env.POSTGRES_USER = 'appuser';
      process.env.POSTGRES_PASSWORD = 'secret123';
      process.env.POSTGRES_DB = 'production';
      
      const url = getDatabaseUrl();
      
      expect(url).toBe('postgresql://appuser:secret123@prod-db.internal:5433/production?sslmode=disable');
    });
  });
});
