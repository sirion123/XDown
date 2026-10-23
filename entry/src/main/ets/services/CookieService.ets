// CookieService - 平台 Cookie 管理服务
// 负责 cookie 的存储、检索、格式转换和清理
// Cookie 以原始格式存储（name=value; name2=value2），并持久化到 Preferences
// 当前只支持 X；未来新增平台时扩展 PlatformId 与 PLATFORMS。
import preferences from '@ohos.data.preferences'
import { Context } from '@kit.AbilityKit'

const COOKIE_STORE: string = 'cookie_store'
const PLATFORMS: PlatformId[] = ['x']

export type PlatformId = 'x'

// CookieService - 单例服务，管理平台 Cookie
export class CookieService {
  private cookies: Map<string, string> = new Map()
  private loginStatus: Map<string, boolean> = new Map()
  private prefs: preferences.Preferences | null = null

  // 同步加载已保存的登录 Cookie（必须在页面创建前调用）
  init(context: Context): void {
    try {
      this.prefs = preferences.getPreferencesSync(context, { name: COOKIE_STORE })
      for (const platform of PLATFORMS) {
        const value: string = this.prefs.getSync(platform, '') as string
        if (value.length > 0) {
          this.cookies.set(platform, value)
          this.loginStatus.set(platform, true)
        }
      }
    } catch (e) {
      // Preferences 不可用时退回内存 Cookie
    }
  }

  // 存储平台 cookie（原始格式: "name=value; name2=value2"）
  setCookies(platform: PlatformId, cookies: string): void {
    this.cookies.set(platform, cookies)
    this.loginStatus.set(platform, true)
    try {
      if (this.prefs) {
        this.prefs.putSync(platform, cookies)
        this.prefs.flushSync()
      }
    } catch (e) {
      // 持久化失败时仍保留内存登录态
    }
  }

  getCookies(platform: PlatformId): string | null {
    return this.cookies.get(platform) ?? null
  }

  // 用于 http.createHttp 的 header.Cookie
  getCookieHeader(platform: PlatformId): string | null {
    return this.cookies.get(platform) ?? null
  }

  clearCookies(platform: PlatformId): void {
    this.cookies.delete(platform)
    this.loginStatus.set(platform, false)
    try {
      if (this.prefs) {
        this.prefs.deleteSync(platform)
        this.prefs.flushSync()
      }
    } catch (e) {
      // 忽略持久化删除失败
    }
  }

  isLoggedIn(platform: PlatformId): boolean {
    return this.loginStatus.get(platform) ?? false
  }

  getLoggedInPlatforms(): PlatformId[] {
    return this.isLoggedIn('x') ? ['x'] : []
  }

  // 将 WebView 提取的 cookie 字符串转换为 Netscape 格式（向后兼容）
  static toNetscapeFormat(rawCookies: string, domain: string): string {
    const lines: string[] = ['# Netscape HTTP Cookie File', '# This is a generated file!  Do not edit.', '']
    const pairs = rawCookies.split(';')
    for (const pair of pairs) {
      const trimmed = pair.trim()
      if (trimmed.length === 0) {
        continue
      }
      const eqIdx = trimmed.indexOf('=')
      if (eqIdx < 0) {
        continue
      }
      const name = trimmed.substring(0, eqIdx).trim()
      const value = trimmed.substring(eqIdx + 1).trim()
      lines.push(`${domain}\tTRUE\t/\tTRUE\t0\t${name}\t${value}`)
    }
    return lines.join('\n')
  }

  static getCookieDomain(platform: PlatformId): string {
    switch (platform) {
      case 'x':
        return '.x.com'
      default:
        return ''
    }
  }

  static getPlatformLabel(platform: PlatformId): string {
    switch (platform) {
      case 'x':
        return 'X (Twitter)'
      default:
        return '未知平台'
    }
  }

  static getLoginUrl(platform: PlatformId): string {
    switch (platform) {
      case 'x':
        return 'https://x.com/i/flow/login'
      default:
        return ''
    }
  }
}
