import { Want } from '@kit.AbilityKit'
import { LinkNormalizer } from './LinkNormalizer'

// ShareIntentService - 分享接收服务
export class ShareIntentService {
  // 从 Want 中提取分享文本
  static extractSharedText(want: Want): string | null {
    if (!want) {
      return null
    }

    // 尝试从 want.parameters 中获取分享文本（覆盖各系统/应用使用的键名）
    if (want.parameters) {
      const possibleKeys = [
        'content', 'text', 'shareText', 'sharedText', 'data', 'title', 'subject',
        'ohos.extra.param.key.content', 'ohos.extra.param.key.text',
        'ability.params.stream', 'stream'
      ]
      for (const key of possibleKeys) {
        const value = want.parameters[key]
        if (typeof value === 'string' && value.length > 0) {
          return value
        }
      }

      // 兜底：扫描全部参数，优先返回含 URL 的字符串，其次返回首个非空字符串
      let firstNonEmpty: string | null = null
      for (const key of Object.keys(want.parameters)) {
        const value = want.parameters[key]
        if (typeof value === 'string' && value.length > 0) {
          if (LinkNormalizer.extractUrl(value)) {
            return value
          }
          if (!firstNonEmpty) {
            firstNonEmpty = value
          }
        }
      }
      if (firstNonEmpty) {
        return firstNonEmpty
      }
    }

    // 尝试从 want.uri 获取
    if (want.uri && want.uri.length > 0) {
      return want.uri
    }

    return null
  }

  // 从分享文本中提取 URL
  static extractUrlFromShare(want: Want): string | null {
    const text = ShareIntentService.extractSharedText(want)
    if (!text) {
      return null
    }
    return LinkNormalizer.extractUrl(text)
  }

  // 判断 Want 是否为分享操作
  static isShareIntent(want: Want): boolean {
    if (!want) {
      return false
    }
    if (want.action === 'ohos.want.action.sendData') {
      return true
    }
    if (want.parameters && want.parameters['shareIntent'] !== undefined) {
      return true
    }
    return false
  }
}
