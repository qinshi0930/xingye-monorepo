import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'standalone',
  distDir: '.next',

  // ========== 图片域名配置 ==========
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**',
      },
    ],
    formats: ['image/webp', 'image/avif'],
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
    ];
  },

  // ========== URL 重写规则 ==========
  async rewrites() {
    return [];
  },

  // ========== 性能优化配置 ==========
  compress: true,
  generateEtags: true,
  poweredByHeader: false,
};

export default nextConfig;
