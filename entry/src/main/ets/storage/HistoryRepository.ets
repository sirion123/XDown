import { MediaItem } from '../models/MediaItem'
import { ProviderType } from '../models/ResolveResult'
import preferences from '@ohos.data.preferences'
import { Context } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x0002
const STORE_NAME: string = 'history_store'
const ITEMS_KEY: string = 'history_items'

// 序列化用的显式接口（ArkTS 要求对象字面量必须有对应类型）
interface MediaItemRecord {
  id: string
  provider: ProviderType
  title: string
  thumbnailUrl: string
  filePath: string
  savedToGallery: boolean
  downloadTime: number
  fileSize: number
  fileExists: boolean
}

// HistoryRepository - 历史记录存储（Preferences 持久化版本）
export class HistoryRepository {
  private items: MediaItem[] = []
  private prefs: preferences.Preferences | null = null
  private context: Context | null = null
  private loaded: boolean = false

  // 设置上下文并加载持久化数据（必须在首次使用前调用）
  async init(context: Context): Promise<void> {
    this.context = context
    try {
      this.prefs = await preferences.getPreferences(context, STORE_NAME)
      await this.loadFromStorage()
      this.loaded = true
      hilog.info(DOMAIN, 'HistoryRepository', 'History loaded from Preferences')
    } catch (err) {
      hilog.error(DOMAIN, 'HistoryRepository', `Failed to init Preferences: ${JSON.stringify(err)}`)
      this.items = []
    }
  }

  // 从 Preferences 加载历史记录
  private async loadFromStorage(): Promise<void> {
    if (!this.prefs) {
      return
    }
    try {
      const jsonStr: string = await this.prefs.get(ITEMS_KEY, '') as string
      if (jsonStr.length > 0) {
        this.items = this.deserialize(jsonStr)
      } else {
        this.items = []
      }
    } catch (err) {
      hilog.error(DOMAIN, 'HistoryRepository', `Failed to load from Preferences: ${JSON.stringify(err)}`)
      this.items = []
    }
  }

  // 保存历史记录到 Preferences
  private async saveToStorage(): Promise<void> {
    if (!this.prefs) {
      return
    }
    try {
      const jsonStr: string = this.serialize(this.items)
      await this.prefs.put(ITEMS_KEY, jsonStr)
      await this.prefs.flush()
    } catch (err) {
      hilog.error(DOMAIN, 'HistoryRepository', `Failed to save to Preferences: ${JSON.stringify(err)}`)
    }
  }

  // 序列化 MediaItem 数组为 JSON 字符串
  private serialize(items: MediaItem[]): string {
    const jsonArray: MediaItemRecord[] = items.map((item: MediaItem): MediaItemRecord => {
      return {
        id: item.id,
        provider: item.provider,
        title: item.title,
        thumbnailUrl: item.thumbnailUrl,
        filePath: item.filePath,
        savedToGallery: item.savedToGallery,
        downloadTime: item.downloadTime,
        fileSize: item.fileSize,
        fileExists: item.fileExists
      }
    })
    return JSON.stringify(jsonArray)
  }

  // 反序列化 JSON 字符串为 MediaItem 数组
  private deserialize(jsonStr: string): MediaItem[] {
    try {
      const jsonArray: MediaItemRecord[] = JSON.parse(jsonStr) as MediaItemRecord[]
      return jsonArray.map((record: MediaItemRecord): MediaItem => {
        return new MediaItem(
          record.id,
          record.provider,
          record.title,
          record.thumbnailUrl,
          record.filePath,
          record.savedToGallery,
          record.downloadTime,
          record.fileSize,
          record.fileExists
        )
      })
    } catch (err) {
      hilog.error(DOMAIN, 'HistoryRepository', `Failed to deserialize: ${JSON.stringify(err)}`)
      return []
    }
  }

  // 获取所有历史记录
  getAllItems(): MediaItem[] {
    return this.items.sort((a: MediaItem, b: MediaItem): number => b.downloadTime - a.downloadTime)
  }

  // 添加历史记录
  addItem(item: MediaItem): void {
    this.items.push(item)
    this.saveToStorage()
  }

  // 删除历史记录
  deleteItem(id: string): void {
    this.items = this.items.filter((item: MediaItem): boolean => item.id !== id)
    this.saveToStorage()
  }

  // 清空历史记录（不删除图库文件与临时文件）
  async clearAll(): Promise<void> {
    this.items = []
    await this.saveToStorage()
  }

  // 更新历史记录
  updateItem(id: string, savedToGallery: boolean, fileExists: boolean): void {
    const index: number = this.items.findIndex((item: MediaItem): boolean => item.id === id)
    if (index !== -1) {
      this.items[index].savedToGallery = savedToGallery
      this.items[index].fileExists = fileExists
      this.saveToStorage()
    }
  }

  // 按平台筛选
  filterByProvider(provider: ProviderType): MediaItem[] {
    return this.items.filter((item: MediaItem): boolean => item.provider === provider)
  }

  // 搜索
  search(keyword: string): MediaItem[] {
    const lowerKeyword: string = keyword.toLowerCase()
    return this.items.filter((item: MediaItem): boolean =>
      item.title.toLowerCase().includes(lowerKeyword)
    )
  }

  // 批量删除
  batchDelete(ids: string[]): void {
    this.items = this.items.filter((item: MediaItem): boolean => !ids.includes(item.id))
    this.saveToStorage()
  }
}
