import { webview } from '@kit.ArkWeb'
import { CookieService, PlatformId } from '../services/CookieService'
import { AmbientBackground } from '../components/AmbientBackground'
import { SettingsRepository } from '../storage/SettingsRepository'

// 移动端 UA：与手机浏览器一致，避免平台把内嵌 WebView 识别成平板/桌面
const MOBILE_UA: string =
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36'

// LoginPage - 平台登录页（NavDestination）
// 只负责打开平台网页；检测到有效会话 Cookie 后自动保存并返回，无需用户手动确认。
@Component
export struct LoginPage {
  private navPathStack: NavPathStack = AppStorage.get<NavPathStack>('navPathStack') ?? new NavPathStack()
  private cookieService: CookieService = AppStorage.get<CookieService>('cookieService') ?? new CookieService()
  @State platform: string = ''
  @State loginUrl: string = ''
  @State pageTitle: string = ''
  @State loginStatus: string = '正在加载登录页面...'
  @State isLoggedIn: boolean = false
  @State customBackgroundPath: string = ''
  private settingsRepository: SettingsRepository =
    AppStorage.get<SettingsRepository>('settingsRepository') ?? new SettingsRepository()
  private webController: webview.WebviewController = new webview.WebviewController()
  private pollTimer: number = -1
  private autoSaving: boolean = false
  private closeTimer: number = -1

  aboutToAppear(): void {
    this.platform = AppStorage.get<string>('loginPlatform') ?? ''
    this.loginUrl = AppStorage.get<string>('loginUrl') ?? ''
    this.pageTitle = AppStorage.get<string>('loginPageTitle') ?? '平台登录'
    this.customBackgroundPath = this.settingsRepository.getCustomBackgroundPath()

    if (this.loginUrl.length === 0) {
      this.loginUrl = this.getDefaultLoginUrl(this.platform)
    }
    if (this.pageTitle.length === 0) {
      this.pageTitle = this.getPlatformLabel(this.platform) + ' 登录'
    }

    // X 登录依赖第三方 Cookie
    try {
      webview.WebCookieManager.putAcceptCookieEnabled(true)
      webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(true)
    } catch (e) {
      // 旧版本不支持时忽略
    }

    // SPA 登录（X）不一定触发 onPageEnd，定时检查 Cookie
    this.pollTimer = setInterval(() => {
      this.checkLoginStatus()
    }, 1200)
  }

  aboutToDisappear(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer)
      this.pollTimer = -1
    }
    if (this.closeTimer !== -1) {
      clearTimeout(this.closeTimer)
      this.closeTimer = -1
    }
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        AmbientBackground({ customImagePath: this.customBackgroundPath })

        Column() {
        // 自定义标题栏：全屏布局下避开状态栏
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.arrow_left'))
              .fontSize(20)
              .fontColor([$r('app.color.text_primary')])
          }
          .width(40)
          .height(40)
          .backgroundColor(Color.Transparent)
          .backgroundEffect({
            radius: 20,
            saturation: 1.3,
            color: $r('app.color.glass_fill')
          })
          .border({ width: 1, color: $r('app.color.glass_border') })
          .accessibilityText('返回')
          .onClick(() => {
            this.navPathStack.pop()
          })

          Text(this.pageTitle)
            .fontSize($r('app.float.font_title'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 12 })

          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 44, bottom: 10 })

        // 状态提示
        Row() {
          Circle()
            .width(8)
            .height(8)
            .fill(this.isLoggedIn ? $r('app.color.status_success') : $r('app.color.brand_primary'))

          Text(this.loginStatus)
            .fontSize($r('app.float.font_caption'))
            .fontColor(this.isLoggedIn ? $r('app.color.status_success') : $r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .margin({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundEffect({
          radius: 18,
          saturation: 1.3,
          color: $r('app.color.glass_fill')
        })
        .border({ width: 1, color: $r('app.color.glass_border') })

        // WebView 登录区域（移动端 UA，避免平台按平板/桌面渲染）
        Web({ src: this.loginUrl, controller: this.webController })
          .layoutWeight(1)
          .width('100%')
          .userAgent(MOBILE_UA)
          .domStorageAccess(true)
          .databaseAccess(true)
          .fileAccess(true)
          .mixedMode(MixedMode.All)
          .javaScriptAccess(true)
          .onlineImageAccess(true)
          .imageAccess(true)
          .geolocationAccess(true)
          .mediaPlayGestureAccess(true)
          .cacheMode(CacheMode.Default)
          .wideViewModeAccess(false)
          .overviewModeAccess(false)
          .textZoomRatio(100)
          .onAlert((event) => {
            if (event) {
              event.result.handleConfirm()
            }
            return true
          })
          .onConfirm((event) => {
            if (event) {
              event.result.handleConfirm()
            }
            return true
          })
          .onPrompt((event) => {
            if (event) {
              event.result.handlePromptConfirm(event.value)
            }
            return true
          })
          .onPageEnd(() => {
            this.checkLoginStatus()
          })
          .onPageBegin(() => {
            this.loginStatus = '正在加载...'
          })
          .onErrorReceive((event) => {
            if (event) {
              this.loginStatus = `页面加载失败：${event.error.getErrorInfo()}`
            }
          })
          .onHttpErrorReceive((event) => {
            if (event) {
              this.loginStatus = `页面返回 HTTP ${event.response.getResponseCode()}`
            }
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.navPathStack.pop()
      return true
    })
  }

  private async checkLoginStatus(): Promise<void> {
    if (this.autoSaving) {
      return
    }
    try {
      const currentUrl: string = this.webController.getUrl()
      const lower: string = currentUrl.toLowerCase()

      if (lower.includes('accounts.google.com') || lower.includes('google.com/signin')) {
        this.isLoggedIn = false
        this.loginStatus = '请使用手机号或邮箱登录'
        return
      }

      // 登录是否完成以会话 Cookie 为准，避免 SPA/错误页被误判
      const cookies: string = await this.collectCookies(this.platform)
      if (this.hasSessionCookie(this.platform, cookies)) {
        this.isLoggedIn = true
        this.loginStatus = '登录成功，正在保存...'
        this.autoSaving = true
        await this.persistAndReturn(cookies)
        return
      }

      this.isLoggedIn = false
      const onLoginFlow: boolean = lower.includes('login') || lower.includes('flow') ||
        lower.includes('passport') || lower.includes('signin')
      this.loginStatus = onLoginFlow || currentUrl.length === 0 ?
        '请在页面中完成登录' : `当前页面: ${this.getShortUrl(currentUrl)}`
    } catch (e) {
      this.loginStatus = '无法获取页面状态'
    }
  }

  // 检测到有效 Cookie 后自动保存并返回，不需要“完成登录/保存”
  private async persistAndReturn(cookies: string): Promise<void> {
    this.cookieService.setCookies(this.platform as PlatformId, cookies)
    AppStorage.setOrCreate<string>('loginReturnPlatform', this.platform)
    AppStorage.setOrCreate<string>('loginReturnCookies', cookies)
    AppStorage.setOrCreate<number>('loginChanged', Date.now())
    this.showToast(this.getPlatformLabel(this.platform) + ' 已登录')
    this.closeTimer = setTimeout(() => {
      this.navPathStack.pop()
    }, 300)
  }

  private hasSessionCookie(platform: string, cookies: string): boolean {
    switch (platform) {
      case 'x': {
        const authToken: string = this.getCookieValue(cookies, 'auth_token')
        const csrf: string = this.getCookieValue(cookies, 'ct0')
        let twid: string = this.getCookieValue(cookies, 'twid')
        try {
          twid = decodeURIComponent(twid)
        } catch (e) {
          // twid 可能不是合法百分号编码，保留原值
        }
        const uid: string = twid.replace(/^u=/, '')
        return authToken.length > 20 && csrf.length > 10 && uid.length > 0 && uid !== '0'
      }
      default:
        return false
    }
  }

  private getCookieValue(cookies: string, name: string): string {
    for (const part of cookies.split(';')) {
      const segment: string = part.trim()
      const eq: number = segment.indexOf('=')
      if (eq > 0 && segment.substring(0, eq).trim() === name) {
        return segment.substring(eq + 1)
      }
    }
    return ''
  }

  // X 的 Cookie 可能落在 x.com / twitter.com，逐个域名取并合并
  private async collectCookies(platform: string): Promise<string> {
    try {
      await webview.WebCookieManager.saveCookieAsync()
    } catch (e) {
      // 忽略持久化失败，继续读内存 Cookie
    }

    const merged: Map<string, string> = new Map<string, string>()
    for (const url of this.getCookieUrls(platform)) {
      try {
        const cookies: string = await webview.WebCookieManager.fetchCookie(url, false, true)
        if (!cookies || cookies.length === 0) {
          continue
        }
        for (const part of cookies.split(';')) {
          const segment: string = part.trim()
          const eq: number = segment.indexOf('=')
          if (eq <= 0) {
            continue
          }
          merged.set(segment.substring(0, eq).trim(), segment.substring(eq + 1))
        }
      } catch (e) {
        // 该域名没有 Cookie，继续下一个
      }
    }

    const pairs: string[] = []
    merged.forEach((value: string, name: string) => {
      pairs.push(`${name}=${value}`)
    })
    return pairs.join('; ')
  }

  private getCookieUrls(platform: string): string[] {
    switch (platform) {
      case 'x':
        return ['https://x.com', 'https://twitter.com', 'https://api.x.com']
      default:
        return []
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().openToast({ message })
    } catch (e) {
      // ignore toast errors
    }
  }

  private getDefaultLoginUrl(platform: string): string {
    switch (platform) {
      case 'x':
        return 'https://x.com/i/flow/login'
      default:
        return ''
    }
  }

  private getPlatformLabel(platform: string): string {
    switch (platform) {
      case 'x':
        return 'X'
      default:
        return '平台'
    }
  }

  private getShortUrl(url: string): string {
    if (url.length > 60) {
      return url.substring(0, 57) + '...'
    }
    return url
  }
}
