import { EmptyState } from '../components/EmptyState'
import { TaskCard } from '../components/TaskCard'
import { PlatformBadge } from '../components/PlatformBadge'
import { GlassCard } from '../components/GlassCard'
import { AmbientBackground } from '../components/AmbientBackground'
import { PageHeaderBar } from '../components/PageHeaderBar'
import { AccountRow } from '../components/AccountRow'
import { LinkNormalizer } from '../services/LinkNormalizer'
import { ProviderType } from '../models/ResolveResult'
import { DownloadTask, DownloadStatus } from '../models/DownloadTask'
import { MediaItem } from '../models/MediaItem'
import { DownloadService } from '../services/DownloadService'
import { MediaSaveService } from '../services/MediaSaveService'
import { CookieService, PlatformId } from '../services/CookieService'
import { HistoryRepository } from '../storage/HistoryRepository'
import { SettingsRepository } from '../storage/SettingsRepository'

import { ResolveDetailPage } from './ResolveDetailPage'
import { LoginPage } from './LoginPage'
import { uiMaterial } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { image } from '@kit.ImageKit'

// ========== LazyForEach 数据源 ==========

class TaskDataSource implements IDataSource {
  private tasks: DownloadTask[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.tasks.length
  }

  getData(index: number): DownloadTask {
    return this.tasks[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener)
    if (pos >= 0) {
      this.listeners.splice(pos, 1)
    }
  }

  setData(tasks: DownloadTask[]): void {
    this.tasks = tasks
    this.notifyDataReload()
  }

  private notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded()
    })
  }
}

class HistoryDataSource implements IDataSource {
  private items: MediaItem[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): MediaItem {
    return this.items[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener)
    if (pos >= 0) {
      this.listeners.splice(pos, 1)
    }
  }

  setData(items: MediaItem[]): void {
    this.items = items
    this.notifyDataReload()
  }

  private notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded()
    })
  }
}

// ========== CustomDialog 定义 ==========


@CustomDialog
struct LicenseDialog {
  controller: CustomDialogController

  build() {
    Column() {
      Text('第三方依赖许可证')
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 14 })

      Text('前端使用 HarmonyOS NEXT 原生 SDK，无第三方 npm/ohpm 包。')
        .fontSize($r('app.float.font_body_small'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Text('完整许可证清单详见 docs/THIRD_PARTY_NOTICES.md。')
        .fontSize($r('app.float.font_body_small'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 20 })

      Button('关闭')
        .type(ButtonType.Capsule)
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .width('100%')
        .height($r('app.float.button_height_normal'))
        .onClick(() => {
          this.controller.close()
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 20 })
  }
}

// ========== HomePage 主页面 ==========

@Entry
@Component
struct HomePage {
  @State currentTabIndex: number = 0
  @State inputText: string = ''
  @State identifiedPlatform: ProviderType = ProviderType.UNKNOWN
  @State showError: boolean = false
  @State errorMsg: string = ''
  @State tasks: DownloadTask[] = []
  @State visibleTasks: DownloadTask[] = []
  @State historyItems: MediaItem[] = []
  @State customBackgroundPath: string = ''
  @State previewVisible: boolean = false
  @State previewPath: string = ''
  @State searchKeyword: string = ''
  @State downloadFilter: number = 0
  @State xLoggedIn: boolean = false
  @StorageLink('switchToTab') @Watch('onSwitchToTab') switchToTab: number = -1
  // 登录页写入 Cookie 后自增此值，触发主页刷新登录状态
  @StorageLink('loginChanged') @Watch('onLoginChanged') loginChanged: number = 0

  // 路由栈：通过 AppStorage 共享给 NavDestination 子页面。
  private navPathStack: NavPathStack = new NavPathStack()

  private taskDataSource: TaskDataSource = new TaskDataSource()
  private historyDataSource: HistoryDataSource = new HistoryDataSource()

  private downloadService: DownloadService = AppStorage.get<DownloadService>('downloadService') ?? new DownloadService()
  private mediaSaveService: MediaSaveService = AppStorage.get<MediaSaveService>('mediaSaveService') ?? new MediaSaveService()
  private historyRepository: HistoryRepository = AppStorage.get<HistoryRepository>('historyRepository') ?? new HistoryRepository()
  private settingsRepository: SettingsRepository = AppStorage.get<SettingsRepository>('settingsRepository') ?? new SettingsRepository()
  private cookieService: CookieService = AppStorage.get<CookieService>('cookieService') ?? new CookieService()

  // HarmonyOS 7 沉浸光感：底部悬浮页签的材质（仅在 Tabs 底部 TabBar 作用域内生效）
  // THIN 的模糊更强，背景内容会变成柔和的色块而不是可读文字。
  private tabMaterial: uiMaterial.ImmersiveMaterial = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    materialColor: $r('app.color.glass_material_tint'),
    colorInvert: false,
    applyShadow: true,
    interactive: true,
    lightEffect: { color: $r('app.color.brand_primary') }
  })

  private licenseDialogController: CustomDialogController = new CustomDialogController({
    builder: LicenseDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    cornerRadius: 28,
    systemMaterial: new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THICK,
      applyShadow: true
    })
  })

  private tabNames: string[] = ['首页', '下载', '历史', '设置']
  private tabIcons: Resource[] = [
    $r('sys.symbol.house'),
    $r('sys.symbol.download'),
    $r('sys.symbol.arrow_counterclockwise_clock'),
    $r('sys.symbol.gearshape')
  ]
  private tabIconsSelected: Resource[] = [
    $r('sys.symbol.house_fill'),
    $r('sys.symbol.download'),
    $r('sys.symbol.arrow_counterclockwise_clock'),
    $r('sys.symbol.gearshape_fill')
  ]

  aboutToAppear(): void {
    AppStorage.setOrCreate<NavPathStack>('navPathStack', this.navPathStack)

    try {
      const supported: boolean = uiMaterial.isImmersiveMaterialSupported()
      const level: uiMaterial.MaterialLevel = uiMaterial.getGlobalMaterialLevel()
      hilog.info(0x0000, 'Design', 'immersiveMaterial supported=%{public}s level=%{public}d', `${supported}`, level)
    } catch (err) {
      hilog.warn(0x0000, 'Design', 'immersive material unavailable: %{public}s', JSON.stringify(err))
    }

    // 优先处理已提取的分享 URL
    const shareUrl = AppStorage.get<string>('shareUrl')
    if (shareUrl && shareUrl.length > 0) {
      this.inputText = shareUrl
      AppStorage.setOrCreate<string>('shareUrl', '')
      this.identifiedPlatform = LinkNormalizer.identifyPlatform(shareUrl)
    } else {
      const shareText = AppStorage.get<string>('shareText')
      if (shareText && shareText.length > 0) {
        this.inputText = shareText
        AppStorage.setOrCreate<string>('shareText', '')
        const url = LinkNormalizer.extractUrl(this.inputText)
        if (url) {
          this.identifiedPlatform = LinkNormalizer.identifyPlatform(url)
        }
      }
    }

    this.refreshTasks()
    this.refreshHistory()
    this.customBackgroundPath = this.settingsRepository.getCustomBackgroundPath()
    this.refreshLoginStatus()

    const returnPlatform = AppStorage.get<string>('loginReturnPlatform')
    const returnCookies = AppStorage.get<string>('loginReturnCookies')
    if (returnPlatform && returnCookies) {
      this.cookieService.setCookies(returnPlatform as PlatformId, returnCookies)
      AppStorage.setOrCreate<string>('loginReturnPlatform', '')
      AppStorage.setOrCreate<string>('loginReturnCookies', '')
      this.refreshLoginStatus()
    }
  }

  // 登录状态变更：延迟到下一 tick 刷新，避免在重渲染期间同步改 @State
  private onLoginChanged(): void {
    setTimeout(() => {
      const returnPlatform = AppStorage.get<string>('loginReturnPlatform')
      const returnCookies = AppStorage.get<string>('loginReturnCookies')
      if (returnPlatform && returnCookies) {
        this.cookieService.setCookies(returnPlatform as PlatformId, returnCookies)
        AppStorage.setOrCreate<string>('loginReturnPlatform', '')
        AppStorage.setOrCreate<string>('loginReturnCookies', '')
      }
      this.refreshLoginStatus()
    }, 0)
  }

  private refreshTabData(index: number): void {
    setTimeout(() => {
      if (index === 1) {
        this.refreshTasks()
      } else if (index === 2) {
        this.refreshHistory()
      }
    }, 0)
  }

  private onSwitchToTab(): void {
    const target: number = this.switchToTab
    if (target < 0 || target >= this.tabNames.length) {
      return
    }
    AppStorage.setOrCreate<number>('switchToTab', -1)
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.currentTabIndex = target
      })
      if (target === 1) {
        this.refreshTasks()
      } else if (target === 2) {
        this.refreshHistory()
      }
    }, 0)
  }

  build() {
    Navigation(this.navPathStack) {
      Stack({ alignContent: Alignment.TopStart }) {
        AmbientBackground({ customImagePath: this.customBackgroundPath })

        Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
          TabContent() {
            this.HomeTabContent()
          }
          .tabBar(this.TabBarItem(0))

          TabContent() {
            this.DownloadsTabContent()
          }
          .tabBar(this.TabBarItem(1))

          TabContent() {
            this.HistoryTabContent()
          }
          .tabBar(this.TabBarItem(2))

          TabContent() {
            this.SettingsTabContent()
          }
          .tabBar(this.TabBarItem(3))
        }
        .width('100%')
        .height('100%')
        .barMode(BarMode.Fixed)
        .barHeight($r('app.float.tab_bar_height'))
        .barOverlap(true)
        .barPosition(BarPosition.End)
        .vertical(false)
        .barFloatingStyle({
          barWidth: { smallBarWidth: 340, mediumBarWidth: 340, largeBarWidth: 340 },
          barSideMargin: 16,
          barBottomMargin: -28,
          maskHeight: 0,
          adaptToHandedness: true,
          systemMaterial: this.tabMaterial
        })
        .animationDuration(240)
        .onChange((index: number) => {
          this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseInOut }, () => {
            this.currentTabIndex = index
          })
          this.refreshTabData(index)
        })
      }
      .width('100%')
      .height('100%')
    }
    .navDestination(this.pageMap)
    .hideTitleBar(true)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .backgroundColor($r('app.color.bg_page'))
    .bindContentCover(this.previewVisible, this.PreviewOverlay(), {
      modalTransition: ModalTransition.NONE
    })
  }

  // 应用内预览：直接播放沙箱文件，避免外部播放器没有 file:// 读取权限
  @Builder
  PreviewOverlay() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Video({ src: 'file://' + this.previewPath })
          .layoutWeight(1)
          .width('100%')
          .autoPlay(true)
          .controls(true)
          .objectFit(ImageFit.Contain)
          .backgroundColor(Color.Black)
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 34 })
      .backgroundColor(Color.Black)

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(18)
          .fontColor([Color.White])
      }
      .width(36)
      .height(36)
      .backgroundColor('#66000000')
      .margin({ top: 54, right: 16 })
      .accessibilityText('关闭预览')
      .onClick(() => {
        this.previewVisible = false
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }

  // ========== 底部悬浮玻璃页签 ==========

  @Builder
  TabBarItem(index: number) {
    Column() {
      Column() {
        SymbolGlyph(index === this.currentTabIndex ? this.tabIconsSelected[index] : this.tabIcons[index])
          .fontSize(21)
          .fontColor([index === this.currentTabIndex ? $r('app.color.brand_primary') : $r('app.color.tab_inactive')])

        Text(this.tabNames[index])
          .fontSize($r('app.float.font_micro'))
          .fontColor(index === this.currentTabIndex ? $r('app.color.brand_primary') : $r('app.color.tab_inactive'))
          .fontWeight(index === this.currentTabIndex ? FontWeight.Medium : FontWeight.Normal)
          .margin({ top: 3 })
      }
      .padding({ left: 14, right: 14, top: 5, bottom: 5 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ========== NavDestination 路由映射 ==========

  @Builder
  pageMap(name: string) {
    if (name === 'ResolveDetailPage') {
      ResolveDetailPage()
    } else if (name === 'LoginPage') {
      LoginPage()
    }
  }

  // ========== 通用小组件 ==========

  @Builder
  SectionLabel(text: string) {
    Text(text)
      .fontSize($r('app.float.font_caption'))
      .fontColor($r('app.color.text_tertiary'))
      .fontWeight(FontWeight.Medium)
      .letterSpacing(0.6)
      .width('100%')
      .padding({ left: 4, top: 6, bottom: 2 })
  }

  @Builder
  IconGhost(icon: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(17)
        .fontColor([$r('app.color.text_secondary')])
    }
    .width(36)
    .height(36)
    .backgroundColor($r('app.color.chip_bg'))
    .accessibilityText(label)
    .onClick(() => {
      action()
    })
  }

  // ========== 首页 Tab ==========

  @Builder
  HomeTabContent() {
    Scroll() {
      Column({ space: 18 }) {
        // 标题区
        Column() {
          Text('XDOWN')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_primary'))
            .letterSpacing(2)

          Text('把 X 视频\n留在手机里')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(38)
            .margin({ top: 8 })

          Text('粘贴链接，解析后保存到图库')
            .fontSize($r('app.float.font_body_small'))
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 10 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 10 })

        // 链接输入卡片
        GlassCard({ contentPadding: 16, cornerRadius: 26 }) {
          Column({ space: 12 }) {
            Row() {
              SymbolGlyph($r('sys.symbol.link'))
                .fontSize(18)
                .fontColor([$r('app.color.brand_primary')])

              TextInput({ placeholder: '粘贴 X 视频链接', text: this.inputText })
                .layoutWeight(1)
                .height(40)
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_placeholder'))
                .backgroundColor(Color.Transparent)
                .padding({ left: 8, right: 4 })
                .caretColor($r('app.color.brand_primary'))
                .enterKeyType(EnterKeyType.Search)
                .onChange((value: string) => {
                  this.inputText = value
                  this.showError = false
                  if (value.length > 0) {
                    const url = LinkNormalizer.extractUrl(value)
                    this.identifiedPlatform = url ? LinkNormalizer.identifyPlatform(url) : ProviderType.UNKNOWN
                  } else {
                    this.identifiedPlatform = ProviderType.UNKNOWN
                  }
                })
                .onSubmit(() => {
                  this.onResolve()
                })

              if (this.inputText.length > 0) {
                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                    .fontSize(18)
                    .fontColor([$r('app.color.text_tertiary')])
                }
                .width(32)
                .height(32)
                .backgroundColor(Color.Transparent)
                .accessibilityText('清空输入')
                .onClick(() => {
                  this.inputText = ''
                  this.identifiedPlatform = ProviderType.UNKNOWN
                  this.showError = false
                })
              }
            }
            .width('100%')

            Row() {
              this.PlatformChip('X', $r('app.color.platform_x'))

              Blank()

              Button('解析')
                .type(ButtonType.Capsule)
                .buttonStyle(ButtonStyleMode.EMPHASIZED)
                .height(40)
                .padding({ left: 26, right: 26 })
                .fontSize($r('app.float.font_body_small'))
                .fontWeight(FontWeight.Medium)
                .enabled(this.inputText.length > 0)
                .onClick(() => {
                  this.onResolve()
                })
            }
            .width('100%')

            if (this.showError) {
              Row() {
                SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
                  .fontSize(15)
                  .fontColor([$r('app.color.status_error')])

                Text(this.errorMsg)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.status_error'))
                  .layoutWeight(1)
                  .margin({ left: 6 })
              }
              .width('100%')
              .padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .borderRadius(12)
              .backgroundColor($r('app.color.status_error_bg'))
            }
          }
          .width('100%')
        }

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.info_circle'))
            .fontSize(13)
            .fontColor([$r('app.color.text_tertiary')])

          Text('部分视频需要查看权限，请尝试在设置登录账号后下载')
            .fontSize($r('app.float.font_micro'))
            .fontColor($r('app.color.text_tertiary'))
            .lineHeight(17)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 4, right: 4 })

        Row() {
          SymbolGlyph($r('sys.symbol.checkmark_shield_fill'))
            .fontSize(14)
            .fontColor([$r('app.color.status_success')])

          Text('链接仅在本机处理，不上传')
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_tertiary'))
            .margin({ left: 6 })
        }
        .width('100%')
        .padding({ left: 4 })

        if (this.historyItems.length === 0) {
          Column({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.movie'))
              .fontSize(34)
              .fontColor([$r('app.color.text_tertiary')])

            Text('还没有保存的视频')
              .fontSize($r('app.float.font_body_small'))
              .fontColor($r('app.color.text_secondary'))

            Text('解析并下载后会显示在这里')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        // 最近保存
        if (this.historyItems.length > 0) {
          Column({ space: 10 }) {
            Row() {
              Text('最近保存')
                .fontSize($r('app.float.font_section'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))

              Blank()

              Text('查看历史')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.brand_primary'))
                .onClick(() => {
                  this.switchTab(2)
                })
            }
            .width('100%')
            .padding({ left: 4, right: 4 })

            ForEach(this.historyItems.slice(0, 1), (item: MediaItem) => {
              this.RecentHistoryRow(item)
            }, (item: MediaItem) => item.id)
          }
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .padding({
        left: $r('app.float.page_padding_horizontal'),
        right: $r('app.float.page_padding_horizontal'),
        top: 42,
        bottom: 130
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  PlatformChip(label: string, color: ResourceStr) {
    Row() {
      Circle()
        .width(6)
        .height(6)
        .fill(color)

      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 5 })
    }
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .borderRadius($r('app.float.radius_pill'))
    .backgroundColor($r('app.color.chip_bg'))
    .margin({ right: 6 })
  }

  @Builder
  RecentHistoryRow(item: MediaItem) {
    GlassCard({ contentPadding: 12 }) {
      Row() {
        Stack() {
          if (item.thumbnailUrl.length > 0) {
            Image(item.thumbnailUrl)
              .width(48)
              .height(48)
              .objectFit(ImageFit.Cover)
              .borderRadius(14)
          } else {
            Column()
              .width(48)
              .height(48)
              .borderRadius(14)
              .linearGradient({
                angle: 135,
                colors: [
                  [$r('app.color.brand_primary_light'), 0],
                  [$r('app.color.chip_bg'), 1]
                ]
              })
          }

          if (item.thumbnailUrl.length === 0) {
            SymbolGlyph($r('sys.symbol.movie_fill'))
              .fontSize(18)
              .fontColor([$r('app.color.brand_primary')])
          }
        }
        .width(48)
        .height(48)
        .clip(true)

        Column() {
          Text(item.title.length > 0 ? item.title : '未命名视频')
            .fontSize($r('app.float.font_body_small'))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`${this.formatTime(item.downloadTime)} · ${this.historyStatusText(item)}`)
            .fontSize($r('app.float.font_caption'))
            .fontColor(this.historyStatusColor(item))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })

        SymbolGlyph($r('sys.symbol.play_circle'))
          .fontSize(22)
          .fontColor([$r('app.color.text_tertiary')])
          .onClick(() => {
            this.openHistoryFile(item)
          })
      }
      .width('100%')
    }
  }

  // ========== 下载 Tab ==========

  @Builder
  DownloadsTabContent() {
    Column() {
      PageHeaderBar({ title: '下载', subtitle: `${this.tasks.length} 个任务` })

      Row({ space: 8 }) {
        this.FilterButton('全部', 0)
        this.FilterButton('进行中', 1)
        this.FilterButton('已完成', 2)
      }
      .width('100%')
      .padding({ left: $r('app.float.page_padding_horizontal'), right: $r('app.float.page_padding_horizontal'), bottom: 10 })

      if (this.visibleTasks.length === 0) {
        EmptyState({
          icon: $r('sys.symbol.download'),
          title: this.downloadFilter === 0 ? '暂无下载任务' : '没有符合条件的任务',
          description: '解析后下载，任务会显示在这里'
        })
          .layoutWeight(1)
      } else {
        List() {
          LazyForEach(this.taskDataSource, (task: DownloadTask) => {
            ListItem() {
              TaskCard({
                task: task,
                onPauseCallback: () => {
                  this.downloadService.pauseTask(task.taskId)
                  this.refreshTasks()
                },
                onResumeCallback: () => {
                  this.downloadService.resumeTask(task.taskId)
                  this.refreshTasks()
                },
                onCancelCallback: () => {
                  this.downloadService.cancelTask(task.taskId)
                  this.refreshTasks()
                },
                onRetryCallback: () => {
                  this.downloadService.retryTask(task.taskId)
                  this.refreshTasks()
                },
                onSaveCallback: () => {
                  this.saveToGallery(task)
                },
                onOpenCallback: () => {
                  this.openDownloadedFile(task)
                }
              })
            }
            .margin({ bottom: 10 })
          }, (task: DownloadTask) => task.taskId)

          ListItem() {
            Row().height(120)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: $r('app.float.page_padding_horizontal'), right: $r('app.float.page_padding_horizontal'), top: 2 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  FilterButton(label: string, filter: number) {
    Button(label)
      .type(ButtonType.Capsule)
      .controlSize(ControlSize.SMALL)
      .height(32)
      .fontSize($r('app.float.font_caption'))
      .buttonStyle(this.downloadFilter === filter ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL)
      .onClick(() => {
        this.downloadFilter = filter
        this.refreshTasks()
      })
  }

  // ========== 历史 Tab ==========

  @Builder
  HistoryTabContent() {
    Column() {
      PageHeaderBar({ title: '历史', subtitle: `${this.historyItems.length} 条记录` })

      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(18)
            .fontColor([$r('app.color.text_tertiary')])

          TextInput({ placeholder: '搜索标题或作者', text: this.searchKeyword })
            .layoutWeight(1)
            .height(44)
            .fontSize($r('app.float.font_body_small'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_placeholder'))
            .backgroundColor(Color.Transparent)
            .caretColor($r('app.color.brand_primary'))
            .padding({ left: 8 })
            .onChange((value: string) => {
              this.searchKeyword = value
              this.refreshHistory()
            })
        }
        .width('100%')
        .height(46)
        .padding({ left: 14, right: 14 })
        .borderRadius(23)
        .backgroundEffect({
          radius: 22,
          saturation: 1.3,
          color: $r('app.color.glass_fill')
        })
        .border({ width: 1, color: $r('app.color.glass_border') })
      }
      .width('100%')
      .padding({ left: $r('app.float.page_padding_horizontal'), right: $r('app.float.page_padding_horizontal'), bottom: 10 })

      if (this.historyItems.length === 0) {
        EmptyState({
          icon: $r('sys.symbol.movie'),
          title: this.searchKeyword.length > 0 ? '没有匹配的记录' : '暂无历史记录',
          description: '完成下载后会自动记录在这里'
        })
          .layoutWeight(1)
      } else {
        List() {
          LazyForEach(this.historyDataSource, (item: MediaItem) => {
            ListItem() {
              this.HistoryRow(item)
            }
            .margin({ bottom: 10 })
          }, (item: MediaItem) => item.id)

          ListItem() {
            Row().height(120)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: $r('app.float.page_padding_horizontal'), right: $r('app.float.page_padding_horizontal'), top: 6 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  HistoryRow(item: MediaItem) {
    GlassCard({ contentPadding: 12 }) {
      Row() {
        Stack() {
          if (item.thumbnailUrl.length > 0) {
            Image(item.thumbnailUrl)
              .width(76)
              .height(76)
              .objectFit(ImageFit.Cover)
              .borderRadius(16)
          } else {
            Column()
              .width(76)
              .height(76)
              .borderRadius(16)
              .linearGradient({
                angle: 135,
                colors: [
                  [$r('app.color.brand_primary_light'), 0],
                  [$r('app.color.chip_bg'), 1]
                ]
              })
          }

          if (item.thumbnailUrl.length === 0) {
            SymbolGlyph($r('sys.symbol.movie_fill'))
              .fontSize(24)
              .fontColor([$r('app.color.brand_primary')])
          }
        }
        .width(76)
        .height(76)
        .clip(true)

        Column() {
          Text(item.title.length > 0 ? item.title : '未命名视频')
            .fontSize($r('app.float.font_body_small'))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            PlatformBadge({ provider: item.provider })

            Text(this.formatTime(item.downloadTime))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ left: 8 })
          }
          .margin({ top: 5 })

          Row() {
            Text(this.historyStatusText(item))
              .fontSize($r('app.float.font_caption'))
              .fontColor(this.historyStatusColor(item))

            Text(this.formatSize(item.fileSize))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ left: 8 })
          }
          .margin({ top: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })

        Column({ space: 6 }) {
          if (item.fileExists) {
            this.IconGhost($r('sys.symbol.play_circle'), '打开', () => {
              this.openHistoryFile(item)
            })
          }

          this.IconGhost($r('sys.symbol.trash'), '删除', () => {
            this.historyRepository.deleteItem(item.id)
            this.refreshHistory()
          })
        }
        .margin({ left: 8 })
      }
      .width('100%')
    }
  }

  // ========== 设置 Tab ==========

  @Builder
  SettingsTabContent() {
    Scroll() {
      Column({ space: 12 }) {
        PageHeaderBar({ title: '设置', subtitle: '' })

        this.SectionLabel('外观')
        GlassCard({ contentPadding: 18 }) {
          Column() {
            Row() {
              Column() {
                Text('背景图片')
                  .fontSize($r('app.float.font_body'))
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(FontWeight.Medium)

                Text(this.customBackgroundPath.length > 0 ? '已设置' : '未设置')
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_tertiary'))
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (this.customBackgroundPath.length > 0) {
                Image('file://' + this.customBackgroundPath)
                  .width(48)
                  .height(48)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)
                  .margin({ left: 8 })
              }
            }
            .width('100%')

            Row({ space: 10 }) {
              Button('选择图片')
                .type(ButtonType.Capsule)
                .buttonStyle(ButtonStyleMode.EMPHASIZED)
                .controlSize(ControlSize.SMALL)
                .height(34)
                .layoutWeight(1)
                .fontSize($r('app.float.font_caption'))
                .onClick(() => {
                  this.pickBackground()
                })

              if (this.customBackgroundPath.length > 0) {
                Button('恢复默认')
                  .type(ButtonType.Capsule)
                  .buttonStyle(ButtonStyleMode.NORMAL)
                  .controlSize(ControlSize.SMALL)
                  .height(34)
                  .layoutWeight(1)
                  .fontSize($r('app.float.font_caption'))
                  .onClick(() => {
                    this.clearCustomBackground()
                  })
              }
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .width('100%')
        }

        this.SectionLabel('账号')
        GlassCard({ contentPadding: 18 }) {
          Column() {
            AccountRow({
              name: 'X',
              initial: 'X',
              loggedIn: this.xLoggedIn,
              onLogin: () => {
                this.openLogin('x', 'X 登录')
              },
              onLogout: () => {
                this.clearPlatformSession('x')
              }
            })
          }
          .width('100%')
        }

        this.SectionLabel('存储')
        GlassCard({ contentPadding: 18 }) {
          Column() {
            this.SettingLink($r('sys.symbol.trash'), '清理缓存', '删除未保存的临时文件', () => {
              this.cleanupTempFiles()
            })

            Divider().color($r('app.color.divider')).margin({ top: 12, bottom: 12 })

            this.SettingLink($r('sys.symbol.clock'), '清理历史记录', '仅清空记录，不影响图库', () => {
              this.confirmClearHistory()
            })

            Divider().color($r('app.color.divider')).margin({ top: 12, bottom: 12 })

            this.SettingLink($r('sys.symbol.doc_text'), '第三方许可证', '查看开源组件许可', () => {
              this.licenseDialogController.open()
            })
          }
          .width('100%')
        }

        this.SectionLabel('关于')
        GlassCard({ contentPadding: 18 }) {
          Column() {
            Row() {
              Stack() {
                Circle()
                  .width(52)
                  .height(52)
                  .fill($r('app.color.brand_primary'))

                SymbolGlyph($r('sys.symbol.movie_fill'))
                  .fontSize(24)
                  .fontColor([$r('app.color.text_on_brand')])
              }

              Column() {
                Text('XDown')
                  .fontSize($r('app.float.font_body'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))

                Text('版本 1.0.0')
                  .fontSize($r('app.float.font_caption'))
                  .fontColor($r('app.color.text_tertiary'))
                  .margin({ top: 3 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12 })

              Text('本地')
                .fontSize($r('app.float.font_micro'))
                .fontColor($r('app.color.status_success'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius($r('app.float.radius_pill'))
                .backgroundColor($r('app.color.status_success_bg'))
            }
            .width('100%')

            Text('所有处理均在本机完成')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_tertiary'))
              .lineHeight(17)
              .margin({ top: 14 })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({
        left: $r('app.float.page_padding_horizontal'),
        right: $r('app.float.page_padding_horizontal'),
        top: 42,
        bottom: 130
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  SettingLink(icon: Resource, title: string, subtitle: string, action: () => void) {
    Row() {
      Stack() {
        Circle()
          .width(34)
          .height(34)
          .fill($r('app.color.chip_bg'))

        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([$r('app.color.text_secondary')])
      }

      Column() {
        Text(title)
          .fontSize($r('app.float.font_body_small'))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)

        Text(subtitle)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('app.color.text_tertiary')])
    }
    .width('100%')
    .onClick(() => {
      action()
    })
  }

  // ========== 辅助方法 ==========

  private switchTab(index: number): void {
    this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseInOut }, () => {
      this.currentTabIndex = index
    })
    this.refreshTabData(index)
  }

  private openLogin(platform: PlatformId, title: string): void {
    AppStorage.setOrCreate<string>('loginPlatform', platform)
    AppStorage.setOrCreate<string>('loginUrl', CookieService.getLoginUrl(platform))
    AppStorage.setOrCreate<string>('loginPageTitle', title)
    this.navPathStack.pushPath({ name: 'LoginPage' })
  }

  private taskStatusText(status: DownloadStatus): string {
    switch (status) {
      case DownloadStatus.QUEUED:
        return '排队中'
      case DownloadStatus.DOWNLOADING:
        return '下载中'
      case DownloadStatus.COMPLETED:
        return '已完成'
      case DownloadStatus.FAILED:
        return '下载失败'
      case DownloadStatus.CANCELLED:
        return '已取消'
      default:
        return '处理中'
    }
  }

  private taskStatusColor(status: DownloadStatus): ResourceStr {
    switch (status) {
      case DownloadStatus.COMPLETED:
        return $r('app.color.status_success')
      case DownloadStatus.FAILED:
        return $r('app.color.status_error')
      case DownloadStatus.DOWNLOADING:
        return $r('app.color.brand_primary')
      default:
        return $r('app.color.text_tertiary')
    }
  }

  private historyStatusText(item: MediaItem): string {
    if (item.savedToGallery) {
      return '已保存到图库'
    } else if (!item.fileExists) {
      return '本地文件已删除'
    }
    return '临时文件'
  }

  private historyStatusColor(item: MediaItem): ResourceStr {
    if (item.savedToGallery) {
      return $r('app.color.status_success')
    } else if (!item.fileExists) {
      return $r('app.color.status_error')
    }
    return $r('app.color.status_warning')
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().openToast({ message })
    } catch (e) {
      // ignore toast errors
    }
  }

  private clearPlatformSession(platform: PlatformId): void {
    this.cookieService.clearCookies(platform)
    // 清掉 WebView 的会话 Cookie，否则下次打开登录页会直接命中旧登录态
    try {
      webview.WebCookieManager.clearAllCookiesSync()
      webview.WebCookieManager.saveCookieAsync()
    } catch (e) {
      // 清理失败时至少保证应用侧登录态已删除
    }
    AppStorage.setOrCreate<string>('loginReturnPlatform', '')
    AppStorage.setOrCreate<string>('loginReturnCookies', '')
    this.refreshLoginStatus()
  }

  private refreshLoginStatus(): void {
    this.xLoggedIn = this.cookieService.isLoggedIn('x')
  }

  private async saveToGallery(task: DownloadTask): Promise<void> {
    if (task.status !== DownloadStatus.COMPLETED) {
      this.showToast('请等待下载完成后再保存')
      return
    }
    if (task.targetFilePath.length === 0) {
      this.showToast('文件路径无效')
      return
    }

    const isVideo: boolean = task.formatId.includes('mp4')
    const result: string | null = isVideo ?
      await this.mediaSaveService.saveVideoToGallery(task.targetFilePath, task.title) :
      await this.mediaSaveService.saveImageToGallery(task.targetFilePath, task.title)

    if (result) {
      this.showToast('已保存到图库')
      this.historyRepository.updateItem(DownloadService.historyId(task.taskId), true, true)
      this.refreshHistory()
    } else {
      this.showToast('保存失败，请重试')
    }
  }

  private async openDownloadedFile(task: DownloadTask): Promise<void> {
    this.openPreview(task.targetFilePath)
  }

  private async openHistoryFile(item: MediaItem): Promise<void> {
    if (!this.openPreview(item.filePath)) {
      this.historyRepository.updateItem(item.id, item.savedToGallery, false)
      this.refreshHistory()
    }
  }

  private openPreview(path: string): boolean {
    if (path.length === 0) {
      this.showToast('文件路径无效')
      return false
    }
    try {
      if (!fileIo.accessSync(path)) {
        this.showToast('文件不存在，可能已被清理')
        return false
      }
    } catch (e) {
      this.showToast('文件不存在，可能已被清理')
      return false
    }
    this.previewPath = path
    this.previewVisible = true
    return true
  }

  private async pickBackground(): Promise<void> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      })
      if (!result.photoUris || result.photoUris.length === 0) {
        return
      }

      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const timestamp: number = Date.now()
      const rawPath = `${context.filesDir}/custom_background_raw_${timestamp}.jpg`
      const dest = `${context.filesDir}/custom_background_${timestamp}.jpg`

      // 先复制到沙箱，再从文件描述符解码；部分相册 URI 直接交给 image 解码会失败。
      const srcFile = fileIo.openSync(result.photoUris[0], fileIo.OpenMode.READ_ONLY)
      fileIo.copyFileSync(srcFile.fd, rawPath)
      fileIo.closeSync(srcFile)

      let finalPath: string = rawPath
      try {
        // 统一解码为 baseline JPEG，避免相册原图的 progressive/ICC 导致解码失败，
        // 同时限制长边，降低大图内存占用。
        const imageSource = image.createImageSource(rawPath)
        const info = await imageSource.getImageInfo()
        const maxDim: number = 2200
        const scale: number = Math.min(1, maxDim / Math.max(info.size.width, info.size.height))
        const pixelMap = await imageSource.createPixelMap({
          desiredSize: {
            width: Math.max(1, Math.round(info.size.width * scale)),
            height: Math.max(1, Math.round(info.size.height * scale))
          }
        })
        const packer = image.createImagePacker()
        const buffer = await packer.packing(pixelMap, { format: 'image/jpeg', quality: 90 })
        const destFile = fileIo.openSync(dest,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
        fileIo.writeSync(destFile.fd, buffer)
        fileIo.closeSync(destFile)
        pixelMap.release()
        imageSource.release()
        packer.release()
        finalPath = dest
        try {
          fileIo.unlinkSync(rawPath)
        } catch (e) {
          // 原图副本清理失败不影响使用
        }
      } catch (decodeErr) {
        // 解码失败时保留原始文件作为兜底，Image 组件仍可尝试直接显示
        hilog.warn(0x0000, 'Design', 'background decode failed, fallback to raw: %{public}s',
          JSON.stringify(decodeErr))
      }

      const oldPath = this.customBackgroundPath
      this.customBackgroundPath = finalPath
      this.settingsRepository.setCustomBackgroundPath(finalPath)
      if (oldPath.length > 0 && oldPath !== finalPath) {
        try {
          fileIo.unlinkSync(oldPath)
        } catch (err) {
          // 旧文件可能已被清理，忽略
        }
      }
      this.showToast('背景图片已更新')
    } catch (err) {
      hilog.warn(0x0000, 'Design', 'pickBackground failed: %{public}s', JSON.stringify(err))
      this.showToast('选择图片失败，请重试')
    }
  }

  private clearCustomBackground(): void {
    const oldPath = this.customBackgroundPath
    this.customBackgroundPath = ''
    this.settingsRepository.setCustomBackgroundPath('')
    if (oldPath.length > 0) {
      try {
        fileIo.unlinkSync(oldPath)
      } catch (err) {
        // 文件可能已不存在
      }
    }
    this.showToast('已恢复默认背景')
  }

  private confirmClearHistory(): void {
    this.getUIContext().showAlertDialog({
      title: '清理历史记录',
      message: '仅清空历史记录，不会删除图库中的视频。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清理',
        action: async () => {
          await this.historyRepository.clearAll()
          this.downloadService.clearFinishedTasks()
          this.refreshTasks()
          this.refreshHistory()
          this.showToast('历史记录已清理')
        }
      }
    })
  }

  private async cleanupTempFiles(): Promise<void> {
    const items: MediaItem[] = this.historyRepository.getAllItems()
    let cleanedCount: number = 0

    for (const item of items) {
      if (!item.savedToGallery && item.fileExists && item.filePath.length > 0) {
        const success: boolean = await this.mediaSaveService.deleteTempFile(item.filePath)
        if (success) {
          this.historyRepository.updateItem(item.id, false, false)
          cleanedCount++
        }
      }
    }

    this.showToast(
      cleanedCount > 0 ? `已清理 ${cleanedCount} 个临时文件` : '没有需要清理的临时文件'
    )
    this.refreshHistory()
  }

  private onResolve(): void {
    this.showError = false
    this.errorMsg = ''

    const url = LinkNormalizer.extractUrl(this.inputText)
    if (!url) {
      this.showError = true
      this.errorMsg = '未检测到有效链接'
      return
    }

    if (!LinkNormalizer.isValidUrl(url)) {
      this.showError = true
      this.errorMsg = '链接格式无效'
      return
    }

    const platform = LinkNormalizer.identifyPlatform(url)
    this.identifiedPlatform = platform

    if (platform === ProviderType.UNKNOWN) {
      this.showError = true
      this.errorMsg = '暂不支持该平台的链接'
      return
    }

    AppStorage.setOrCreate<string>('resolveUrl', url)
    AppStorage.setOrCreate<ProviderType>('resolvePlatform', platform)
    setTimeout(() => {
      this.navPathStack.pushPath({ name: 'ResolveDetailPage' })
    }, 0)
  }

  private refreshTasks(): void {
    this.tasks = this.downloadService.getAllTasks()
    let visible: DownloadTask[] = this.tasks
    if (this.downloadFilter === 1) {
      visible = this.tasks.filter((task: DownloadTask) => {
        return task.status === DownloadStatus.DOWNLOADING || task.status === DownloadStatus.QUEUED ||
          task.status === DownloadStatus.RESOLVING || task.status === DownloadStatus.SAVING
      })
    } else if (this.downloadFilter === 2) {
      visible = this.tasks.filter((task: DownloadTask) => {
        return task.status === DownloadStatus.COMPLETED
      })
    }
    this.visibleTasks = visible
    this.taskDataSource.setData(visible)
  }

  private refreshHistory(): void {
    let items: MediaItem[] = this.historyRepository.getAllItems()
    if (this.searchKeyword.length > 0) {
      items = items.filter(item =>
        item.title.toLowerCase().includes(this.searchKeyword.toLowerCase())
      )
    }
    this.historyItems = items
    this.historyDataSource.setData(this.historyItems)
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `${month}-${day} ${hours}:${minutes}`
  }

  private formatSize(bytes: number): string {
    if (bytes >= 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`
    } else if (bytes >= 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
    } else {
      return `${(bytes / 1024).toFixed(1)} KB`
    }
  }
}
