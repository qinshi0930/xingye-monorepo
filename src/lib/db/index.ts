import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema';

declare global {
  var db: ReturnType<typeof createDb> | undefined;
}

/**
 * 获取数据库连接 URL
 * 优先使用完整的 DATABASE_URL，否则根据分散的环境变量拼接
 */
export function getDatabaseUrl(): string {
  // 检查 DATABASE_URL 是否存在且不为空
  if (process.env.DATABASE_URL && process.env.DATABASE_URL.trim() !== '') {
    return process.env.DATABASE_URL;
  }

  // 根据分散的环境变量拼接
  const host = process.env.POSTGRES_HOST || 'localhost';
  const port = process.env.POSTGRES_PORT || '5432';
  const user = process.env.POSTGRES_USER || 'postgres';
  const password = process.env.POSTGRES_PASSWORD || '';
  const database = process.env.POSTGRES_DB || 'mydb';
  const sslmode = 'disable';

  // 构建连接字符串
  const creds = password ? `${user}:${password}` : user;
  return `postgresql://${creds}@${host}:${port}/${database}?sslmode=${sslmode}`;
}

function createDb() {
  const pool = new Pool({
    connectionString: getDatabaseUrl(),
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000
  });

  return drizzle(pool, { schema });
}

// Singleton pattern: prevent multiple connections in development
export const db = globalThis.db ?? createDb();

if (process.env.NODE_ENV !== 'production') {
  globalThis.db = db;
}

export { schema };
