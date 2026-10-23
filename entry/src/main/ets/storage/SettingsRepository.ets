import preferences from '@ohos.data.preferences'
import { Context } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x0003
const STORE_NAME: string = 'settings_store'
const KEY_CUSTOM_BACKGROUND: string = 'custom_background_path'
const KEY_THEME_COLOR: string = 'theme_color'

// SettingsRepository - 设置存储（Preferences 持久化版本）
export class SettingsRepository {
  private customBackgroundPath: string = ''
  private themeColor: string = 'iris'
  private prefs: preferences.Preferences | null = null
  private loaded: boolean = false

  // 设置上下文并加载持久化数据（必须在首次使用前调用）
  async init(context: Context): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(context, STORE_NAME)
      await this.loadFromStorage()
      this.loaded = true
      hilog.info(DOMAIN, 'SettingsRepository', 'Settings loaded from Preferences')
    } catch (err) {
      hilog.error(DOMAIN, 'SettingsRepository', `Failed to init Preferences: ${JSON.stringify(err)}`)
    }
  }

  // 从 Preferences 加载设置
  private async loadFromStorage(): Promise<void> {
    if (!this.prefs) {
      return
    }
    try {
      this.customBackgroundPath = await this.prefs.get(KEY_CUSTOM_BACKGROUND, '') as string
      this.themeColor = await this.prefs.get(KEY_THEME_COLOR, 'iris') as string
    } catch (err) {
      hilog.error(DOMAIN, 'SettingsRepository', `Failed to load from Preferences: ${JSON.stringify(err)}`)
    }
  }

  // 保存设置到 Preferences
  private async saveToStorage(): Promise<void> {
    if (!this.prefs) {
      return
    }
    try {
      await this.prefs.put(KEY_CUSTOM_BACKGROUND, this.customBackgroundPath)
      await this.prefs.put(KEY_THEME_COLOR, this.themeColor)
      await this.prefs.flush()
    } catch (err) {
      hilog.error(DOMAIN, 'SettingsRepository', `Failed to save to Preferences: ${JSON.stringify(err)}`)
    }
  }

  // 自定义背景图片（应用沙箱内的文件路径；空字符串表示使用渐变背景）
  getCustomBackgroundPath(): string {
    return this.customBackgroundPath
  }

  setCustomBackgroundPath(path: string): void {
    this.customBackgroundPath = path
    this.saveToStorage()
  }

  // 主题色
  getThemeColor(): string {
    return this.themeColor
  }

  setThemeColor(id: string): void {
    this.themeColor = id
    this.saveToStorage()
  }
}
