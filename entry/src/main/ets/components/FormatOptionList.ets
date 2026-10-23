import { FormatOption } from '../models/FormatOption'
import { AppTheme } from '../models/AppTheme'

// FormatOptionList - 下载格式选择：玻璃行 + 轻量单选指示
@Component
export struct FormatOptionList {
  @StorageLink('themeColorId') themeColorId: string = 'iris'
  @Prop formats: FormatOption[] = []
  @State selectedIndex: number = 0
  onSelectCallback?: (format: FormatOption) => void

  build() {
    Column({ space: 10 }) {
      ForEach(this.formats, (format: FormatOption, index: number) => {
        Row() {
          Column() {
            Row() {
              Text(format.label)
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Medium)

              if (index === 0) {
                Text('推荐')
                  .fontSize($r('app.float.font_micro'))
                  .fontColor(AppTheme.primary(this.themeColorId))
                  .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                  .borderRadius($r('app.float.radius_pill'))
                  .backgroundColor(AppTheme.light(this.themeColorId))
                  .margin({ left: 8 })
              }
            }

            Row() {
              Text(`${format.width}×${format.height}`)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_tertiary'))

              Text('·')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_tertiary'))
                .margin({ left: 6, right: 6 })

              Text(format.sizeBytes !== null ? this.formatSize(format.sizeBytes) : '大小未知')
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_tertiary'))
            }
            .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Stack() {
            Circle()
              .width(22)
              .height(22)
              .fill(Color.Transparent)
              .stroke(index === this.selectedIndex ? AppTheme.primary(this.themeColorId) : $r('app.color.divider'))
              .strokeWidth(1.5)

            if (index === this.selectedIndex) {
              Circle()
                .width(12)
                .height(12)
                .fill(AppTheme.primary(this.themeColorId))
            }
          }
          .margin({ left: 12 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .borderRadius(18)
        .backgroundColor(index === this.selectedIndex ? $r('app.color.bg_selected') : $r('app.color.glass_fill'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .border({
          width: index === this.selectedIndex ? 1.5 : 1,
          color: index === this.selectedIndex ? AppTheme.primary(this.themeColorId) : $r('app.color.glass_border')
        })
        .onClick(() => {
          this.selectedIndex = index
          if (this.onSelectCallback) {
            this.onSelectCallback(format)
          }
        })
      }, (format: FormatOption) => format.id)
    }
    .width('100%')
  }

  private formatSize(bytes: number): string {
    if (bytes >= 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`
    } else if (bytes >= 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
    } else if (bytes >= 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`
    } else {
      return `${bytes} B`
    }
  }
}
