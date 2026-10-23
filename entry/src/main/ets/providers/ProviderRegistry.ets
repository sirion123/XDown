import { ProviderAdapter } from './ProviderAdapter'
import { ProviderType } from '../models/ResolveResult'

// ProviderRegistry - 平台适配器注册表
export class ProviderRegistry {
  private adapters: Map<ProviderType, ProviderAdapter> = new Map()

  // 注册适配器
  register(adapter: ProviderAdapter, type: ProviderType): void {
    this.adapters.set(type, adapter)
  }

  // 根据 URL 查找适配器
  findAdapter(url: string): ProviderAdapter | null {
    for (const adapter of this.adapters.values()) {
      if (adapter.canHandle(url)) {
        return adapter
      }
    }
    return null
  }

  // 根据 ProviderType 查找适配器
  getAdapter(type: ProviderType): ProviderAdapter | null {
    return this.adapters.get(type) || null
  }

  // 获取所有已注册的 Provider
  getRegisteredProviders(): ProviderType[] {
    return Array.from(this.adapters.keys())
  }
}
