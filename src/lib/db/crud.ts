import { eq, desc, like, and, sql } from 'drizzle-orm';
import { db, schema } from './index';
import type { NewUser, NewPost, User, Post } from './schema';
import * as cache from '@/lib/redis/cache';
import { CACHE_TTL, CACHE_PREFIX, buildCacheKey, buildListCacheKey } from '@/lib/redis/config';

// ============ User Operations ============

export async function createUser(data: NewUser): Promise<User[]> {
  const result = await db.insert(schema.users).values(data).returning();
  return result;
}

export async function getUserById(id: number): Promise<User | undefined> {
  const cacheKey = buildCacheKey(CACHE_PREFIX.USER, id);

  return cache.getOrSet(
    cacheKey,
    async () => {
      const result = await db
        .select()
        .from(schema.users)
        .where(eq(schema.users.id, id))
        .limit(1);
      return result[0];
    },
    CACHE_TTL.USER
  );
}

export async function getUserByEmail(email: string): Promise<User | undefined> {
  const cacheKey = buildCacheKey(CACHE_PREFIX.USER_EMAIL, email);

  return cache.getOrSet(
    cacheKey,
    async () => {
      const result = await db
        .select()
        .from(schema.users)
        .where(eq(schema.users.email, email))
        .limit(1);
      return result[0];
    },
    CACHE_TTL.USER
  );
}

export async function getUserByUsername(
  username: string
): Promise<User | undefined> {
  const cacheKey = buildCacheKey(CACHE_PREFIX.USERNAME, username);

  return cache.getOrSet(
    cacheKey,
    async () => {
      const result = await db
        .select()
        .from(schema.users)
        .where(eq(schema.users.username, username))
        .limit(1);
      return result[0];
    },
    CACHE_TTL.USER
  );
}

export async function updateUser(
  id: number,
  data: Partial<NewUser>
): Promise<User[]> {
  const result = await db
    .update(schema.users)
    .set({ ...data, updatedAt: new Date() })
    .where(eq(schema.users.id, id))
    .returning();

  // 清除相关缓存
  await invalidateUserCache(id);
  if (data.email) {
    await cache.del(buildCacheKey(CACHE_PREFIX.USER_EMAIL, data.email));
  }

  return result;
}

export async function deleteUser(id: number): Promise<void> {
  // 先获取用户信息以清除缓存
  const user = await getUserById(id);

  await db.delete(schema.users).where(eq(schema.users.id, id));

  // 清除缓存
  if (user) {
    await invalidateUserCache(id, user.email, user.username);
  }
}

export async function getAllUsers(): Promise<User[]> {
  // 用户列表变化较频繁，使用较短 TTL
  const cacheKey = buildCacheKey(CACHE_PREFIX.USER, 'all');

  return cache.getOrSet(
    cacheKey,
    async () => {
      return db.select().from(schema.users).orderBy(desc(schema.users.createdAt));
    },
    CACHE_TTL.POST_LIST
  );
}

/**
 * 清除用户相关缓存
 */
async function invalidateUserCache(
  id: number,
  email?: string,
  username?: string
): Promise<void> {
  const keysToDelete: string[] = [
    buildCacheKey(CACHE_PREFIX.USER, id),
    buildCacheKey(CACHE_PREFIX.USER, 'all'),
  ];

  if (email) {
    keysToDelete.push(buildCacheKey(CACHE_PREFIX.USER_EMAIL, email));
  }
  if (username) {
    keysToDelete.push(buildCacheKey(CACHE_PREFIX.USERNAME, username));
  }

  await Promise.all(keysToDelete.map((key) => cache.del(key)));
}

// ============ Post Operations ============

export async function createPost(data: NewPost): Promise<Post[]> {
  const result = await db.insert(schema.posts).values(data).returning();

  // 清除作者的文章列表缓存
  await cache.clear(buildCacheKey(CACHE_PREFIX.POSTS_AUTHOR, data.authorId));

  return result;
}

export async function getPostById(id: number): Promise<Post | undefined> {
  const cacheKey = buildCacheKey(CACHE_PREFIX.POST, id);

  return cache.getOrSet(
    cacheKey,
    async () => {
      const result = await db
        .select()
        .from(schema.posts)
        .where(eq(schema.posts.id, id))
        .limit(1);
      return result[0];
    },
    CACHE_TTL.POST
  );
}

export async function getPostBySlug(slug: string): Promise<Post | undefined> {
  const cacheKey = buildCacheKey(CACHE_PREFIX.POST_SLUG, slug);

  return cache.getOrSet(
    cacheKey,
    async () => {
      const result = await db
        .select()
        .from(schema.posts)
        .where(eq(schema.posts.slug, slug))
        .limit(1);
      return result[0];
    },
    CACHE_TTL.POST
  );
}

export async function getPublishedPosts(limit = 10, offset = 0): Promise<Post[]> {
  const cacheKey = buildListCacheKey(CACHE_PREFIX.POSTS_LIST, {
    published: true,
    limit,
    offset,
  });

  return cache.getOrSet(
    cacheKey,
    async () => {
      return db
        .select()
        .from(schema.posts)
        .where(eq(schema.posts.published, true))
        .orderBy(desc(schema.posts.publishedAt))
        .limit(limit)
        .offset(offset);
    },
    CACHE_TTL.POST_LIST
  );
}

export async function getPostsByAuthor(
  authorId: number,
  limit = 10
): Promise<Post[]> {
  const cacheKey = buildListCacheKey(CACHE_PREFIX.POSTS_AUTHOR, {
    authorId,
    limit,
  });

  return cache.getOrSet(
    cacheKey,
    async () => {
      return db
        .select()
        .from(schema.posts)
        .where(eq(schema.posts.authorId, authorId))
        .orderBy(desc(schema.posts.createdAt))
        .limit(limit);
    },
    CACHE_TTL.POST_LIST
  );
}

export async function updatePost(
  id: number,
  data: Partial<NewPost>
): Promise<Post[]> {
  // 先获取旧数据以清除缓存
  const oldPost = await getPostById(id);

  const result = await db
    .update(schema.posts)
    .set({ ...data, updatedAt: new Date() })
    .where(eq(schema.posts.id, id))
    .returning();

  // 清除相关缓存
  if (oldPost) {
    await invalidatePostCache(id, oldPost.slug, oldPost.authorId);
  }

  return result;
}

export async function deletePost(id: number): Promise<void> {
  // 先获取文章信息以清除缓存
  const post = await getPostById(id);

  await db.delete(schema.posts).where(eq(schema.posts.id, id));

  // 清除缓存
  if (post) {
    await invalidatePostCache(id, post.slug, post.authorId);
  }
}

export async function publishPost(id: number): Promise<Post[]> {
  const result = await db
    .update(schema.posts)
    .set({ published: true, publishedAt: new Date(), updatedAt: new Date() })
    .where(eq(schema.posts.id, id))
    .returning();

  // 清除相关缓存
  const post = result[0];
  if (post) {
    await invalidatePostCache(id, post.slug, post.authorId);
    // 清除已发布文章列表缓存
    await cache.clear(`${CACHE_PREFIX.POSTS_LIST}*`);
  }

  return result;
}

export async function incrementPostViews(id: number): Promise<void> {
  await db
    .update(schema.posts)
    .set({ viewCount: sql`${schema.posts.viewCount} + 1` })
    .where(eq(schema.posts.id, id));

  // 更新缓存中的浏览数（如果存在）
  const cacheKey = buildCacheKey(CACHE_PREFIX.POST, id);
  const cached = await cache.get<Post>(cacheKey);
  if (cached) {
    cached.viewCount += 1;
    await cache.set(cacheKey, cached, CACHE_TTL.POST);
  }
}

export async function searchPosts(query: string, limit = 10): Promise<Post[]> {
  // 搜索不缓存，因为查询参数变化太多
  return db
    .select()
    .from(schema.posts)
    .where(
      and(
        eq(schema.posts.published, true),
        like(schema.posts.title, `%${query}%`)
      )
    )
    .orderBy(desc(schema.posts.publishedAt))
    .limit(limit);
}

/**
 * 清除文章相关缓存
 */
async function invalidatePostCache(
  id: number,
  slug?: string,
  authorId?: number
): Promise<void> {
  const keysToDelete: string[] = [
    buildCacheKey(CACHE_PREFIX.POST, id),
  ];

  if (slug) {
    keysToDelete.push(buildCacheKey(CACHE_PREFIX.POST_SLUG, slug));
  }

  await Promise.all(keysToDelete.map((key) => cache.del(key)));

  // 清除列表缓存
  await cache.clear(`${CACHE_PREFIX.POSTS_LIST}*`);

  if (authorId) {
    await cache.clear(buildCacheKey(CACHE_PREFIX.POSTS_AUTHOR, authorId) + '*');
  }
}
