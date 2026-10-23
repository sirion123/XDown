import { ResolveResult } from '../models/ResolveResult'
import { ProviderError } from '../models/ProviderError'

// ProviderAdapter - 平台适配器接口
export interface ProviderAdapter {
  // 判断是否可以处理该 URL
  canHandle(url: string): boolean

  // 解析视频链接，返回 ResolveResult 或 ProviderError
  // cookies 为可选的 Netscape 格式 cookie 字符串，用于需要登录的平台
  resolve(url: string, cookies?: string): Promise<ResolveResult | ProviderError>

  // 获取 Provider 名称
  getProviderName(): string
}
