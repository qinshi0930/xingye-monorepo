import '@testing-library/jest-dom'

// 设置 TextEncoder/TextDecoder (pg 模块需要)
import { TextEncoder, TextDecoder } from 'util'
global.TextEncoder = TextEncoder
global.TextDecoder = TextDecoder

// 设置 setImmediate/clearImmediate (pino 日志库需要)
import { setImmediate, clearImmediate } from 'timers'
global.setImmediate = setImmediate
global.clearImmediate = clearImmediate

// Optional: configure or set up a testing framework before each test
// If you delete this file, remove `setupFilesAfterEnv` from `jest.config.ts`

// Mock Next.js router
jest.mock('next/navigation', () => ({
  useRouter() {
    return {
      push: jest.fn(),
      replace: jest.fn(),
      refresh: jest.fn(),
      back: jest.fn(),
      forward: jest.fn(),
      prefetch: jest.fn(),
    }
  },
  usePathname() {
    return ''
  },
  useSearchParams() {
    return new URLSearchParams()
  },
}))

// Mock next/image
jest.mock('next/image', () => ({
  __esModule: true,
  default: function Image(props) {
    return React.createElement('img', { ...props, alt: props.alt || '' })
  },
}))

// Mock React for jest.setup.js
import React from 'react'
