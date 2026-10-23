import { ProviderRegistry } from '../providers/ProviderRegistry'
import { XProvider } from '../providers/XProvider'
import { ResolveResult, ProviderType } from '../models/ResolveResult'
import { ProviderError, ErrorCode } from '../models/ProviderError'
import { LinkNormalizer } from './LinkNormalizer'
import { CookieService, PlatformId } from './CookieService'

// ResolveService - 解析服务（纯本地 Provider）
// 未来接入新平台：实现 ProviderAdapter，在 registerProviders 中注册，并扩展 mapToPlatformId。
export class ResolveService {
  private registry: ProviderRegistry
  private cookieService: CookieService

  constructor() {
    this.registry = new ProviderRegistry()
    this.cookieService = AppStorage.get<CookieService>('cookieService') ?? new CookieService()
    this.registerProviders()
  }

  private registerProviders(): void {
    this.registry.register(new XProvider(), ProviderType.X)
  }

  async resolve(url: string): Promise<ResolveResult | ProviderError> {
    if (!LinkNormalizer.isValidUrl(url)) {
      return new ProviderError(ErrorCode.UNSUPPORTED, '无效的链接', false)
    }

    const platform = LinkNormalizer.identifyPlatform(url)
    if (platform === ProviderType.UNKNOWN) {
      return new ProviderError(ErrorCode.UNSUPPORTED, '暂不支持该平台的链接', false)
    }

    const adapter = this.registry.getAdapter(platform)
    if (!adapter) {
      return new ProviderError(ErrorCode.UNSUPPORTED, '暂不支持该平台', false)
    }

    const platformId = this.mapToPlatformId(platform)
    let cookies: string | undefined = undefined
    if (platformId && this.cookieService.isLoggedIn(platformId)) {
      cookies = this.cookieService.getCookieHeader(platformId) ?? undefined
    }

    return await adapter.resolve(url, cookies)
  }

  getRegisteredProviders(): ProviderType[] {
    return this.registry.getRegisteredProviders()
  }

  private mapToPlatformId(platform: ProviderType): PlatformId | null {
    switch (platform) {
      case ProviderType.X:
        return 'x'
      default:
        return null
    }
  }
}
