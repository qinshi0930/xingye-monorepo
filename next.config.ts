import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'standalone',
  distDir: '.next',

  // ========== 图片域名配置 ==========
  images: {
    // 允许加载图片的远程域名
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**',
      },
    ],
    // 图片格式优化
    formats: ['image/webp', 'image/avif'],
    // 图片缓存时间（秒）
    minimumCacheTTL: 60,
  },

  // ========== HTTP 安全头配置 ==========
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=63072000; includeSubDomains; preload',
          },
        ],
      },
    ];
  },

  // ========== URL 重定向规则 ==========
  async redirects() {
    return [
      // www 到非 www 重定向（SEO 优化）
      {
        source: '/:path*',
        has: [
          {
            type: 'host',
            value: 'www.localhost',
          },
        ],
        destination: 'http://localhost:8080/:path*',
        permanent: true,
      },
      // 示例：旧文章链接重定向
      // {
      //   source: '/blog/:slug',
      //   destination: '/posts/:slug',
      //   permanent: true,
      // },
    ];
  },

  // ========== URL 重写规则 ==========
  async rewrites() {
    return [
      // 示例：API 版本重写
      // {
      //   source: '/api/v1/:path*',
      //   destination: '/api/:path*',
      // },
    ];
  },

  // ========== 性能优化配置 ==========
  compress: true,
  generateEtags: true,
  poweredByHeader: false,
};

export default nextConfig;
