// AmbientBackground - 氛围背景
// 用户未选择背景图片时使用渐变 + 氛围光；选择后使用应用沙箱内的自定义图片。
@Component
export struct AmbientBackground {
  @Prop customImagePath: string = ''

  build() {
    Stack() {
      if (this.customImagePath.length > 0) {
        Image('file://' + this.customImagePath)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)

        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.bg_scrim'))

        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [
              [$r('app.color.bg_gradient_start'), 0],
              [Color.Transparent, 0.25],
              [Color.Transparent, 0.8],
              [$r('app.color.bg_gradient_end'), 1]
            ]
          })
          .opacity(0.7)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 160,
            colors: [
              [$r('app.color.bg_gradient_start'), 0],
              [$r('app.color.bg_gradient_end'), 1]
            ]
          })

        this.Glow($r('app.color.ambient_blue'), 460, '-30%', '-22%', 0.9)
        this.Glow($r('app.color.ambient_cyan'), 380, '48%', '8%', 0.8)
        this.Glow($r('app.color.ambient_violet'), 420, '-24%', '52%', 0.78)
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }

  @Builder
  Glow(color: ResourceColor, size: number, x: Length, y: Length, opacity: number) {
    Column()
      .width(size)
      .height(size)
      .borderRadius(size / 2)
      .radialGradient({
        center: ['50%', '50%'],
        radius: '50%',
        colors: [
          [color, 0],
          [Color.Transparent, 1]
        ]
      })
      .position({ x: x, y: y })
      .opacity(opacity)
  }
}
