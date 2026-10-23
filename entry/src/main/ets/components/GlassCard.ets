// GlassCard - 沉浸式玻璃卡片容器
// 官方限制：系统沉浸材质（systemMaterial）只在标题栏 / 底部 TabBar / 弹窗等
// 作用域生效，普通内容卡片无法直接使用。这里用“更强的背景模糊 + 饱和度
// + 半透明赋色 + 顶部斜向高光 + 阴影”叠出玻璃层次，而不是单纯的白色毛玻璃。
@Component
export struct GlassCard {
  @Prop contentPadding: Length = 18
  @Prop cornerRadius: Length = 24
  @Prop fill: ResourceColor = $r('app.color.glass_fill')
  @Prop blurEnabled: boolean = true
  @BuilderParam content: () => void = this.emptyContent

  @Builder
  emptyContent() {
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.contentPadding)
    .borderRadius(this.cornerRadius)
    .backgroundEffect({
      radius: this.blurEnabled ? 42 : 0,
      saturation: 1.5,
      brightness: 1.02,
      color: this.fill
    })
    .linearGradient({
      angle: 180,
      colors: [
        [$r('app.color.glass_highlight'), 0],
        [Color.Transparent, 0.5],
        [Color.Transparent, 1]
      ]
    })
    .border({ width: 1, color: $r('app.color.glass_border') })
    .clip(true)
    .shadow({
      radius: 24,
      color: $r('app.color.shadow_color'),
      offsetX: 0,
      offsetY: 8
    })
  }
}
