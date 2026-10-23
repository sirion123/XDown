// EmptyState - 空状态：系统符号 + 玻璃底托
@Component
export struct EmptyState {
  @Prop icon: Resource = $r('sys.symbol.doc_text')
  @Prop title: string = '暂无数据'
  @Prop description: string = ''
  @Prop actionText: string = ''
  onActionCallback?: () => void

  build() {
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

        SymbolGlyph(this.icon)
          .fontSize(38)
          .fontColor([$r('app.color.brand_primary')])
      }
      .margin({ bottom: $r('app.float.spacing_xl') })

      Text(this.title)
        .fontSize($r('app.float.font_section'))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: $r('app.float.spacing_sm') })

      if (this.description.length > 0) {
        Text(this.description)
          .fontSize($r('app.float.font_body_small'))
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: $r('app.float.spacing_xl') })
      }

      if (this.actionText.length > 0 && this.onActionCallback) {
        Button(this.actionText)
          .type(ButtonType.Capsule)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .fontSize($r('app.float.font_body_small'))
          .height($r('app.float.button_height_normal'))
          .padding({ left: 20, right: 20 })
          .onClick(() => {
            if (this.onActionCallback) {
              this.onActionCallback()
            }
          })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 32, right: 32 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
