import { ResolveResult, ProviderType, WatermarkStatus } from '../models/ResolveResult'
import { ProviderError, ErrorCode } from '../models/ProviderError'
import { FormatOption, DownloadMode } from '../models/FormatOption'
import { ResolveService } from '../services/ResolveService'
import { FormatOptionList } from '../components/FormatOptionList'
import { PlatformBadge } from '../components/PlatformBadge'
import { GlassCard } from '../components/GlassCard'
import { AmbientBackground } from '../components/AmbientBackground'
import { DownloadService } from '../services/DownloadService'
import { SettingsRepository } from '../storage/SettingsRepository'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppTheme } from '../models/AppTheme'

// ResolveDetailPage - 解析详情页（NavDestination）：全幅封面 + 玻璃信息面板 + 底部操作条
@Component
export struct ResolveDetailPage {
  @StorageLink('themeColorId') themeColorId: string = 'iris'
  private navPathStack: NavPathStack = AppStorage.get<NavPathStack>('navPathStack') ?? new NavPathStack()
  @State isResolving: boolean = true
  @State resolveResult: ResolveResult | null = null
  @State resolveError: ProviderError | null = null
  @State selectedFormat: FormatOption | null = null
  @State customBackgroundPath: string = ''
  private settingsRepository: SettingsRepository =
    AppStorage.get<SettingsRepository>('settingsRepository') ?? new SettingsRepository()
  private url: string = ''
  private platform: ProviderType = ProviderType.UNKNOWN
  private resolveService: ResolveService = AppStorage.get<ResolveService>('resolveService') ?? new ResolveService()
  private downloadService: DownloadService = AppStorage.get<DownloadService>('downloadService') ?? new DownloadService()

  aboutToAppear(): void {
    this.url = AppStorage.get<string>('resolveUrl') ?? ''
    this.platform = AppStorage.get<ProviderType>('resolvePlatform') ?? ProviderType.UNKNOWN
    this.customBackgroundPath = this.settingsRepository.getCustomBackgroundPath()
    this.doResolve()
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        AmbientBackground({ customImagePath: this.customBackgroundPath })

        if (this.isResolving) {
          this.LoadingState()
        }

        if (!this.isResolving && this.resolveError) {
          this.ErrorState(this.resolveError)
        }

        if (!this.isResolving && this.resolveResult) {
          this.ResultContent(this.resolveResult)
        }

        // 自定义返回按钮（玻璃圆形）
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(20)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(40)
        .height(40)
        .margin({ left: 16, top: 52 })
        .backgroundColor(Color.Transparent)
        .backgroundEffect({
          radius: 22,
          saturation: 1.3,
          color: $r('app.color.glass_fill')
        })
        .border({ width: 1, color: $r('app.color.glass_border') })
        .accessibilityText('返回')
        .onClick(() => {
          this.navPathStack.pop()
        })
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

  @Builder
  LoadingState() {
    Column() {
      Stack() {
        Column()
          .width(92)
          .height(92)
          .borderRadius(46)
          .backgroundEffect({
            radius: 46,
            saturation: 1.3,
            color: $r('app.color.glass_fill')
          })
          .border({ width: 1, color: $r('app.color.glass_border') })
          .clip(true)

        LoadingProgress()
          .width(38)
          .height(38)
          .color(AppTheme.primary(this.themeColorId))
      }
      .margin({ bottom: 18 })

      Text('正在本地解析')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Text('链接只在设备本地处理，不会上传')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ErrorState(error: ProviderError) {
    Column() {
      Stack() {
        Column()
          .width(92)
          .height(92)
          .borderRadius(46)
          .backgroundEffect({
            radius: 46,
            saturation: 1.3,
            color: $r('app.color.glass_fill')
          })
          .border({ width: 1, color: $r('app.color.glass_border') })
          .clip(true)

        SymbolGlyph(this.errorIcon(error.code))
          .fontSize(36)
          .fontColor([$r('app.color.status_error')])
      }
      .margin({ bottom: 20 })

      Text(this.errorTitle(error.code))
        .fontSize($r('app.float.font_section'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)

      Text(this.errorMessage(error))
        .fontSize($r('app.float.font_body_small'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeight(20)
        .margin({ top: 8, left: 32, right: 32 })

      if (error.retryable) {
        Button('重新解析')
          .type(ButtonType.Capsule)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .height($r('app.float.button_height_normal'))
          .padding({ left: 26, right: 26 })
          .margin({ top: 24 })
          .onClick(() => {
            this.isResolving = true
            this.resolveError = null
            this.doResolve()
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ResultContent(result: ResolveResult) {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column() {
          // 封面
          Stack({ alignContent: Alignment.BottomStart }) {
            if (result.thumbnailUrl.length > 0) {
              Image(result.thumbnailUrl)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
            } else {
              Column()
                .width('100%')
                .height('100%')
                .linearGradient({
                  angle: 135,
                  colors: [
                    [$r('app.color.ambient_blue'), 0],
                    [$r('app.color.ambient_violet'), 1]
                  ]
                })
            }

            Column()
              .width('100%')
              .height(140)
              .linearGradient({
                angle: 180,
                colors: [
                  [$r('app.color.cover_scrim_start'), 0],
                  [$r('app.color.cover_scrim_end'), 1]
                ]
              })

            Row() {
              PlatformBadge({ provider: result.provider, onDark: true })

              Text(this.formatDuration(result.durationSeconds))
                .fontSize($r('app.float.font_caption'))
                .fontColor(Color.White)
                .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                .borderRadius($r('app.float.radius_pill'))
                .backgroundColor('#4D000000')
                .margin({ left: 8 })
            }
            .padding({ left: 16, bottom: 14 })
          }
          .width('100%')
          .height(210)
          .borderRadius($r('app.float.radius_panel'))
          .clip(true)
          .margin({ bottom: 16 })

          // 标题与作者
          GlassCard({ contentPadding: 18 }) {
            Column() {
              Text(result.title)
                .fontSize($r('app.float.font_title'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Row() {
                Text(result.author.length > 0 ? result.author : '未知作者')
                  .fontSize($r('app.float.font_body_small'))
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)

                if (result.watermarkStatus !== WatermarkStatus.CONFIRMED_CLEAN) {
                  Text(this.watermarkText(result.watermarkStatus))
                    .fontSize($r('app.float.font_caption'))
                    .fontColor(this.watermarkColor(result.watermarkStatus))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius($r('app.float.radius_pill'))
                    .backgroundColor($r('app.color.chip_bg'))
                }
              }
              .width('100%')
              .margin({ top: 10 })
            }
            .width('100%')
          }

          // 警告
          if (result.warnings.length > 0) {
            Column({ space: 6 }) {
              ForEach(result.warnings, (warning: string) => {
                Row() {
                  SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
                    .fontSize(14)
                    .fontColor([$r('app.color.status_warning')])

                  Text(warning)
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.status_warning'))
                    .layoutWeight(1)
                    .margin({ left: 6 })
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 9, bottom: 9 })
                .borderRadius(12)
                .backgroundColor($r('app.color.status_warning_bg'))
              }, (warning: string, index: number) => `${index}`)
            }
            .width('100%')
            .margin({ top: 12 })
          }

          // 格式
          Row() {
            Text('选择下载格式')
              .fontSize($r('app.float.font_section'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))

            Blank()

            Text(`${result.formats.length} 个可用`)
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .padding({ left: 4, right: 4 })
          .margin({ top: 20, bottom: 10 })

          FormatOptionList({
            formats: result.formats,
            onSelectCallback: (format: FormatOption) => {
              this.selectedFormat = format
            }
          })

          // 次级操作
          Button('打开原视频')
            .type(ButtonType.Capsule)
            .buttonStyle(ButtonStyleMode.TEXTUAL)
            .width('100%')
            .height(40)
            .fontSize($r('app.float.font_body_small'))
            .margin({ top: 12 })
            .onClick(() => {
              this.openOriginalVideo()
            })
        }
        .width('100%')
        .padding({
          left: $r('app.float.page_padding_horizontal'),
          right: $r('app.float.page_padding_horizontal'),
          top: 48,
          bottom: 128
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 底部操作条：只保留内容和按钮，不再铺灰色玻璃背板
      Stack({ alignContent: Alignment.Center }) {
        Row() {
          Column() {
            Text(this.compactFormatLabel())
              .fontSize($r('app.float.font_body_small'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.selectedFormat !== null ? this.formatSize(this.selectedFormat.sizeBytes) : '大小未知')
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('下载')
            .type(ButtonType.Capsule)
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .height(44)
            .padding({ left: 18, right: 18 })
            .fontSize($r('app.float.font_body_small'))
            .fontWeight(FontWeight.Medium)
            .enabled(this.selectedFormat !== null)
            .onClick(() => {
              this.onDownload()
            })
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 8, top: 8, bottom: 8 })
      }
      .width(270)
      .height(60)
      .margin({ bottom: 36 })
      .borderRadius(30)
      .backgroundEffect({
        radius: 44,
        saturation: 1.8,
        brightness: 1.05,
        color: Color.Transparent
      })
      .border({ width: 1, color: $r('app.color.glass_border') })
      .clip(true)
    }
    .width('100%')
    .height('100%')
  }

  private async doResolve(): Promise<void> {
    this.isResolving = true
    const result = await this.resolveService.resolve(this.url)
    this.isResolving = false

    if (result instanceof ResolveResult) {
      this.resolveResult = result
      if (result.formats.length > 0) {
        this.selectedFormat = result.formats[0]
      }
    } else if (result instanceof ProviderError) {
      this.resolveError = result
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().openToast({ message })
    } catch (e) {
      // ignore toast errors
    }
  }

  private onDownload(): void {
    if (!this.resolveResult || !this.selectedFormat) {
      return
    }

    if (this.downloadService.isDuplicateTask(this.resolveResult.provider, this.resolveResult.title)) {
      this.getUIContext().showAlertDialog({
        title: '重复下载提示',
        message: '该视频已有正在进行的下载任务，是否继续？',
        primaryButton: {
          value: '取消',
          action: () => {}
        },
        secondaryButton: {
          value: '继续下载',
          action: () => {
            this.createDownloadTask()
          }
        }
      })
      return
    }

    this.createDownloadTask()
  }

  private createDownloadTask(): void {
    if (!this.resolveResult || !this.selectedFormat) {
      return
    }

    const downloadUrl: string = this.selectedFormat.downloadUrl ?? ''
    if (downloadUrl.length === 0) {
      return
    }

    const headers: Record<string, string> = {}
    if (this.selectedFormat.requestHeaders) {
      const source: Record<string, string> = this.selectedFormat.requestHeaders
      for (const key of Object.keys(source)) {
        headers[key] = source[key]
      }
    }
    if (this.resolveResult.canonicalUrl.length > 0) {
      headers['Referer'] = this.resolveResult.canonicalUrl
    }

    const task = this.downloadService.createTask(
      this.resolveResult.provider,
      this.resolveResult.title,
      this.selectedFormat.id,
      downloadUrl,
      headers
    )
    this.downloadService.startDownload(task.taskId)

    AppStorage.setOrCreate<number>('switchToTab', 1)
    this.navPathStack.pop()
  }

  private errorIcon(code: ErrorCode): Resource {
    if (code === ErrorCode.NO_VIDEO) {
      return $r('sys.symbol.movie_slash')
    } else if (code === ErrorCode.ACCESS_RESTRICTED) {
      return $r('sys.symbol.lock')
    }
    return $r('sys.symbol.exclamationmark_circle')
  }

  private errorTitle(code: ErrorCode): string {
    if (code === ErrorCode.NO_VIDEO) {
      return '没有可用视频'
    } else if (code === ErrorCode.ACCESS_RESTRICTED) {
      return '需要登录或权限受限'
    }
    return '解析失败'
  }

  private errorMessage(error: ProviderError): string {
    if (error.code === ErrorCode.NO_VIDEO) {
      return '该帖子未提供可用视频，或当前无法访问。'
    } else if (error.code === ErrorCode.ACCESS_RESTRICTED) {
      return '该内容需要登录或权限受限，暂无法解析。'
    }
    return error.message
  }

  private watermarkText(status: WatermarkStatus): string {
    if (status === WatermarkStatus.CONFIRMED_CLEAN) {
      return '已确认无水印'
    } else if (status === WatermarkStatus.WATERMARKED) {
      return '可能包含水印'
    }
    return '水印状态未知'
  }

  private watermarkColor(status: WatermarkStatus): ResourceStr {
    if (status === WatermarkStatus.CONFIRMED_CLEAN) {
      return $r('app.color.status_success')
    } else if (status === WatermarkStatus.WATERMARKED) {
      return $r('app.color.status_warning')
    }
    return $r('app.color.text_tertiary')
  }

  private formatDuration(seconds: number): string {
    if (seconds <= 0) {
      return '时长未知'
    }
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  private compactFormatLabel(): string {
    if (this.selectedFormat === null) {
      return '请选择格式'
    }
    const parts: string[] = this.selectedFormat.label.split(' ')
    const resolution: string = parts.length > 0 ? parts[0] : this.selectedFormat.label
    let codec: string = ''
    if (this.selectedFormat.label.indexOf('h265') >= 0) {
      codec = 'H.265'
    } else if (this.selectedFormat.label.indexOf('h264') >= 0) {
      codec = 'H.264'
    }
    return codec.length > 0 ? `${resolution} · ${codec}` : resolution
  }

  private formatSize(bytes: number | null): string {
    if (bytes === null || bytes <= 0) {
      return '大小未知'
    }
    if (bytes >= 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`
    } else if (bytes >= 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
    }
    return `${(bytes / 1024).toFixed(1)} KB`
  }

  private openOriginalVideo(): void {
    if (!this.resolveResult) {
      return
    }
    const url: string = this.resolveResult.canonicalUrl
    if (url.length === 0) {
      this.showToast('无法获取原始链接')
      return
    }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    context.openLink(url).then(() => {
      // 成功打开链接
    }).catch((err: BusinessError) => {
      this.showToast('无法打开链接')
    })
  }
}
