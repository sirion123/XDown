import { ProviderType } from '../models/ResolveResult'

// LinkNormalizer - 链接规范化服务
// 当前仅接入 X；未来新增平台时，在 X_DOMAINS 同级增加域名表并扩展 identifyPlatform。
export class LinkNormalizer {
  private static X_DOMAINS = ['x.com', 'twitter.com', 'www.x.com', 'www.twitter.com', 'mobile.x.com']

  // 从文本中提取 URL
  static extractUrl(text: string): string | null {
    if (!text || text.trim().length === 0) {
      return null
    }
    const urlRegex = /https?:\/\/[^\s<>"']+/gi
    const match = text.match(urlRegex)
    if (match && match.length > 0) {
      return match[0]
    }
    return null
  }

  // 移除分享文案，只保留链接
  static cleanShareText(text: string): string {
    if (!text) {
      return ''
    }
    const url = LinkNormalizer.extractUrl(text)
    return url || text.trim()
  }

  // 识别平台类型
  static identifyPlatform(url: string): ProviderType {
    if (!url) {
      return ProviderType.UNKNOWN
    }
    const lowerUrl = url.toLowerCase()
    for (const domain of LinkNormalizer.X_DOMAINS) {
      if (lowerUrl.includes(domain)) {
        return ProviderType.X
      }
    }
    return ProviderType.UNKNOWN
  }

  // 校验 URL 合法性
  static isValidUrl(url: string): boolean {
    if (!url || url.trim().length === 0) {
      return false
    }
    try {
      const lowerUrl: string = url.toLowerCase()
      if (!lowerUrl.startsWith('http://') && !lowerUrl.startsWith('https://')) {
        return false
      }
      const noProtocol: string = lowerUrl.replace(/^https?:\/\//, '')
      const slashIndex: number = noProtocol.indexOf('/')
      const hostname: string = slashIndex > 0 ? noProtocol.substring(0, slashIndex) : noProtocol
      if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '0.0.0.0') {
        return false
      }
      const ipParts: string[] = hostname.split('.')
      if (ipParts.length === 4) {
        const first: number = parseInt(ipParts[0])
        if (first === 10 || first === 172 || first === 192) {
          return false
        }
      }
      return true
    } catch (e) {
      return false
    }
  }

  static isKnownPlatform(url: string): boolean {
    return LinkNormalizer.identifyPlatform(url) !== ProviderType.UNKNOWN
  }

  static getPlatformDisplayName(type: ProviderType): string {
    switch (type) {
      case ProviderType.X:
        return 'X'
      default:
        return '未知'
    }
  }
}
