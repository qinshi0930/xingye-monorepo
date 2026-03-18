import { defineConfig } from 'drizzle-kit';
import { getDatabaseUrl } from './src/lib/db/index';

export default defineConfig({
  // Path to schema file(s)
  schema: './src/lib/db/schema.ts',

  // Output directory for migrations
  out: './drizzle',

  // Database dialect
  dialect: 'postgresql',

  // Database connection credentials
  // 优先使用 DATABASE_URL，否则使用分散的环境变量
  dbCredentials: {
    url: process.env.DATABASE_URL || getDatabaseUrl(),
  },

  // Verbose output
  verbose: true,

  // Strict mode - fail on warnings
  strict: true,

  // Migrations configuration
  migrations: {
    table: '__drizzle_migrations',
    schema: 'public',
  },
});
