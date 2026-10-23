import { ProviderType } from '../models/ResolveResult'
import { LinkNormalizer } from '../services/LinkNormalizer'

// PlatformBadge - 平台标识：色点 + 名称，避免使用 Emoji，保持与系统图标一致
@Component
export struct PlatformBadge {
  @Prop provider: ProviderType = ProviderType.UNKNOWN
  @Prop onDark: boolean = false

  build() {
    Row() {
      Circle()
        .width(6)
        .height(6)
        .fill(this.onDark ? Color.White : this.getColor())

      Text(LinkNormalizer.getPlatformDisplayName(this.provider))
        .fontSize($r('app.float.font_caption'))
        .fontColor(this.onDark ? Color.White : $r('app.color.text_secondary'))
        .fontWeight(FontWeight.Medium)
        .margin({ left: 6 })
    }
    .padding({ left: 9, right: 9, top: 4, bottom: 4 })
    .borderRadius($r('app.float.radius_pill'))
    .backgroundColor(this.onDark ? '#4D000000' : $r('app.color.chip_bg'))
  }

  private getColor(): ResourceStr {
    switch (this.provider) {
      case ProviderType.X:
        return $r('app.color.platform_x')
      default:
        return $r('app.color.text_tertiary')
    }
  }
}
