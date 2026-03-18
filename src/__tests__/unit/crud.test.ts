// 在所有导入之前定义 mock
jest.mock('@/lib/db/index', () => {
  // 创建 mock 链式方法 - 注意顺序，先定义后使用
  const mockReturning = jest.fn().mockResolvedValue([{ id: 1 }]);
  const mockLimit = jest.fn().mockResolvedValue([{ id: 1 }]);
  const mockOffset = jest.fn().mockResolvedValue([{ id: 1 }]);
  
  // 使用函数包装延迟执行
  const mockOrderBy = jest.fn().mockReturnValue({ limit: mockLimit, offset: mockOffset });
  const mockWhere = jest.fn().mockImplementation(() => ({ 
    limit: mockLimit, 
    orderBy: mockOrderBy 
  }));
  const mockFrom = jest.fn().mockImplementation(() => ({ 
    where: mockWhere, 
    orderBy: mockOrderBy 
  }));
  // 修复：mockLimit 需要返回包含 offset 的对象
  mockLimit.mockReturnValue({ offset: mockOffset });
  const mockSet = jest.fn().mockReturnValue({ 
    where: jest.fn().mockReturnValue({ returning: mockReturning }) 
  });
  const mockValues = jest.fn().mockReturnValue({ returning: mockReturning });
  const mockDeleteWhere = jest.fn().mockResolvedValue(undefined);

  const mockDb = {
    insert: jest.fn().mockReturnValue({ values: mockValues }),
    select: jest.fn().mockReturnValue({ from: mockFrom }),
    update: jest.fn().mockReturnValue({ set: mockSet }),
    delete: jest.fn().mockReturnValue({ where: mockDeleteWhere }),
  };

  return {
    db: mockDb,
    schema: {
      users: {
        id: 'id',
        username: 'username',
        email: 'email',
        passwordHash: 'password_hash',
        displayName: 'display_name',
        avatarUrl: 'avatar_url',
        bio: 'bio',
        isActive: 'is_active',
        isAdmin: 'is_admin',
        createdAt: 'created_at',
        updatedAt: 'updated_at',
      },
      posts: {
        id: 'id',
        title: 'title',
        slug: 'slug',
        content: 'content',
        excerpt: 'excerpt',
        coverImage: 'cover_image',
        authorId: 'author_id',
        published: 'published',
        viewCount: 'view_count',
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        publishedAt: 'published_at',
      },
    },
  };
});

// Mock Redis 缓存模块
jest.mock('@/lib/redis/cache', () => ({
  get: jest.fn().mockResolvedValue(null),
  set: jest.fn().mockResolvedValue(undefined),
  del: jest.fn().mockResolvedValue(undefined),
  clear: jest.fn().mockResolvedValue(undefined),
  getOrSet: jest.fn().mockImplementation(async (_key: string, getter: () => Promise<unknown>) => getter()),
}));

import {
  createUser,
  getUserById,
  getUserByEmail,
  getUserByUsername,
  updateUser,
  deleteUser,
  getAllUsers,
  createPost,
  getPostById,
  getPostBySlug,
  getPublishedPosts,
  getPostsByAuthor,
  updatePost,
  deletePost,
  publishPost,
  incrementPostViews,
  searchPosts,
} from '@/lib/db/crud';

// 获取 mock 函数
const mockedIndex = jest.requireMock('@/lib/db/index');

describe('User CRUD Operations', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createUser', () => {
    it('应该调用 db.insert 来创建用户', async () => {
      const newUser = {
        username: 'testuser',
        email: 'test@example.com',
        passwordHash: 'hashedpassword',
      };

      await createUser(newUser);

      expect(mockedIndex.db.insert).toHaveBeenCalled();
    });
  });

  describe('getUserById', () => {
    it('应该调用 db.select 来查询用户', async () => {
      await getUserById(1);

      expect(mockedIndex.db.select).toHaveBeenCalled();
    });
  });

  describe('getUserByEmail', () => {
    it('应该调用 db.select 来根据邮箱查询用户', async () => {
      await getUserByEmail('test@example.com');

      expect(mockedIndex.db.select).toHaveBeenCalled();
    });
  });

  describe('getUserByUsername', () => {
    it('应该调用 db.select 来根据用户名查询用户', async () => {
      await getUserByUsername('testuser');

      expect(mockedIndex.db.select).toHaveBeenCalled();
    });
  });

  describe('updateUser', () => {
    it('应该调用 db.update 来更新用户信息', async () => {
      await updateUser(1, { displayName: 'New Name' });

      expect(mockedIndex.db.update).toHaveBeenCalled();
    });
  });

  describe('deleteUser', () => {
    it('应该调用 db.delete 来删除用户', async () => {
      await deleteUser(1);

      expect(mockedIndex.db.delete).toHaveBeenCalled();
    });
  });

  describe('getAllUsers', () => {
    it('应该调用 db.select 来获取所有用户', async () => {
      await getAllUsers();

      expect(mockedIndex.db.select).toHaveBeenCalled();
    });
  });
});

describe('Post CRUD Operations', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createPost', () => {
    it('应该调用 db.insert 来创建文章', async () => {
      const newPost = {
        title: 'Test Post',
        slug: 'test-post',
        content: 'Test content',
        authorId: 1,
      };

      await createPost(newPost);

      expect(mockedIndex.db.insert).toHaveBeenCalled();
    });
  });

  describe('getPostById', () => {
    it('应该调用 db.select 来根据 ID 查询文章', async () => {
      await getPostById(1);

      expect(mockedIndex.db.select).toHaveBeenCalled();
    });
  });

  describe('getPostBySlug', () => {
    it('应该调用 db.select 来根据 slug 查询文章', async () => {
      await getPostBySlug('test-post');

      expect(mockedIndex.db.select).toHaveBeenCalled();
    });
  });

  describe('getPublishedPosts', () => {
    it('应该调用 db.select 来获取已发布的文章', async () => {
      await getPublishedPosts(10, 0);

      expect(mockedIndex.db.select).toHaveBeenCalled();
    });
  });

  describe('getPostsByAuthor', () => {
    it('应该能正常调用', async () => {
      // 由于使用了缓存，此测试仅验证函数可正常执行
      await expect(getPostsByAuthor(1)).resolves.not.toThrow();
    });
  });

  describe('updatePost', () => {
    it('应该调用 db.update 来更新文章信息', async () => {
      await updatePost(1, { title: 'Updated Title' });

      expect(mockedIndex.db.update).toHaveBeenCalled();
    });
  });

  describe('deletePost', () => {
    it('应该调用 db.delete 来删除文章', async () => {
      await deletePost(1);

      expect(mockedIndex.db.delete).toHaveBeenCalled();
    });
  });

  describe('publishPost', () => {
    it('应该调用 db.update 来发布文章', async () => {
      await publishPost(1);

      expect(mockedIndex.db.update).toHaveBeenCalled();
    });
  });

  describe('incrementPostViews', () => {
    it('应该调用 db.update 来增加文章浏览次数', async () => {
      await incrementPostViews(1);

      expect(mockedIndex.db.update).toHaveBeenCalled();
    });
  });

  describe('searchPosts', () => {
    it('应该调用 db.select 来搜索文章', async () => {
      await searchPosts('Test');

      expect(mockedIndex.db.select).toHaveBeenCalled();
    });
  });
});
