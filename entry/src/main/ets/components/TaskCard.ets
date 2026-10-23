import { DownloadTask, DownloadStatus } from '../models/DownloadTask'
import { LinkNormalizer } from '../services/LinkNormalizer'
import { GlassCard } from './GlassCard'
import { AppTheme } from '../models/AppTheme'

// TaskCard - 下载任务卡片（玻璃卡片 + 状态胶囊 + 图标操作）
@Component
export struct TaskCard {
  @StorageLink('themeColorId') themeColorId: string = 'iris'
  @ObjectLink task: DownloadTask
  onPauseCallback?: () => void
  onResumeCallback?: () => void
  onCancelCallback?: () => void
  onRetryCallback?: () => void
  onSaveCallback?: () => void
  onOpenCallback?: () => void

  build() {
    GlassCard({ contentPadding: 16 }) {
      Column() {
        Row() {
          // 平台图标底托
          Stack() {
            Circle()
              .width(40)
              .height(40)
              .fill(AppTheme.light(this.themeColorId))

            SymbolGlyph($r('sys.symbol.movie_fill'))
              .fontSize(19)
              .fontColor([AppTheme.primary(this.themeColorId)])
          }

          Column() {
            Row() {
              Text(LinkNormalizer.getPlatformDisplayName(this.task.provider))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_tertiary'))

              Blank()

              Text(this.getStatusText())
                .fontSize($r('app.float.font_caption'))
                .fontColor(this.getStatusColor())
                .fontWeight(FontWeight.Medium)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .borderRadius($r('app.float.radius_pill'))
                .backgroundColor(this.getStatusBg())
            }
            .width('100%')

            Text(this.task.title.length > 0 ? this.task.title : '未命名视频')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
        }
        .width('100%')

        // 下载进度
        if (this.task.status === DownloadStatus.DOWNLOADING || this.task.status === DownloadStatus.SAVING) {
          Column() {
            Progress({ value: this.task.progress, total: 100, type: ProgressType.Linear })
              .width('100%')
              .height(4)
              .color(AppTheme.primary(this.themeColorId))
              .backgroundColor($r('app.color.chip_bg'))
              .borderRadius(2)

            Row() {
              Text(`${this.task.progress}%`)
                .fontSize($r('app.float.font_caption'))
                .fontColor(AppTheme.primary(this.themeColorId))

              Blank()

              Text(this.formatSpeed(this.task.speed))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            .margin({ top: 6 })
          }
          .width('100%')
          .margin({ top: 12 })
        }

        if (this.task.status === DownloadStatus.FAILED && this.task.errorMsg.length > 0) {
          Text(this.task.errorMsg)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.status_error'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 10 })
        }

        // 操作区
        Row() {
          if (this.task.status === DownloadStatus.DOWNLOADING) {
            this.IconButton($r('sys.symbol.pause'), '暂停', () => {
              if (this.onPauseCallback) {
                this.onPauseCallback()
              }
            })
          }

          if (this.task.status === DownloadStatus.QUEUED) {
            this.IconButton($r('sys.symbol.play_fill'), '继续', () => {
              if (this.onResumeCallback) {
                this.onResumeCallback()
              }
            })
          }

          if (this.task.status === DownloadStatus.DOWNLOADING || this.task.status === DownloadStatus.QUEUED) {
            this.IconButton($r('sys.symbol.xmark'), '取消', () => {
              if (this.onCancelCallback) {
                this.onCancelCallback()
              }
            })
          }

          if (this.task.status === DownloadStatus.FAILED || this.task.status === DownloadStatus.CANCELLED) {
            this.IconButton($r('sys.symbol.arrow_clockwise'), '重试', () => {
              if (this.onRetryCallback) {
                this.onRetryCallback()
              }
            })
          }

          if (this.task.status === DownloadStatus.COMPLETED) {
            SaveButton({
              icon: SaveIconStyle.FULL_FILLED,
              text: SaveDescription.SAVE_TO_GALLERY,
              buttonType: ButtonType.Capsule
            })
              .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS && this.onSaveCallback) {
                  this.onSaveCallback()
                }
              })

            Blank()

            this.IconButton($r('sys.symbol.play_circle'), '打开文件', () => {
              if (this.onOpenCallback) {
                this.onOpenCallback()
              }
            })
          }
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
    }
  }

  @Builder
  IconButton(icon: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(16)
        .fontColor([$r('app.color.text_secondary')])
    }
    .width(36)
    .height(36)
    .backgroundColor($r('app.color.chip_bg'))
    .accessibilityText(label)
    .margin({ right: 8 })
    .onClick(() => {
      action()
    })
  }

  private getStatusText(): string {
    switch (this.task.status) {
      case DownloadStatus.QUEUED:
        return '排队中'
      case DownloadStatus.RESOLVING:
        return '解析中'
      case DownloadStatus.DOWNLOADING:
        return '下载中'
      case DownloadStatus.SAVING:
        return '保存中'
      case DownloadStatus.COMPLETED:
        return '已完成'
      case DownloadStatus.FAILED:
        return '失败'
      case DownloadStatus.CANCELLED:
        return '已取消'
      default:
        return '未知'
    }
  }

  private getStatusColor(): ResourceStr {
    switch (this.task.status) {
      case DownloadStatus.COMPLETED:
        return $r('app.color.status_success')
      case DownloadStatus.FAILED:
        return $r('app.color.status_error')
      case DownloadStatus.CANCELLED:
        return $r('app.color.text_tertiary')
      case DownloadStatus.DOWNLOADING:
        return AppTheme.primary(this.themeColorId)
      default:
        return $r('app.color.text_secondary')
    }
  }

  private getStatusBg(): ResourceStr {
    switch (this.task.status) {
      case DownloadStatus.COMPLETED:
        return $r('app.color.status_success_bg')
      case DownloadStatus.FAILED:
        return $r('app.color.status_error_bg')
      case DownloadStatus.DOWNLOADING:
        return AppTheme.light(this.themeColorId)
      default:
        return $r('app.color.chip_bg')
    }
  }

  private formatSpeed(bytesPerSecond: number): string {
    if (bytesPerSecond >= 1024 * 1024) {
      return `${(bytesPerSecond / (1024 * 1024)).toFixed(1)} MB/s`
    } else if (bytesPerSecond >= 1024) {
      return `${(bytesPerSecond / 1024).toFixed(1)} KB/s`
    } else {
      return `${bytesPerSecond} B/s`
    }
  }
}
