import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'

// 示例组件测试
function Hello({ name }: { name: string }) {
  return <h1>Hello, {name}!</h1>
}

describe('Hello Component', () => {
  it('renders greeting correctly', () => {
    render(<Hello name="World" />)
    expect(screen.getByText('Hello, World!')).toBeInTheDocument()
  })
})

// 基础工具函数测试示例
describe('Basic Math', () => {
  it('adds 1 + 2 to equal 3', () => {
    expect(1 + 2).toBe(3)
  })
})
