// PageHeaderBar - 页面标题栏（自定义组件，保证副标题随状态刷新）
@Component
export struct PageHeaderBar {
  @Prop title: string = ''
  @Prop subtitle: string = ''

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 3 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: $r('app.float.page_padding_horizontal'),
      right: $r('app.float.page_padding_horizontal'),
      top: 50,
      bottom: 10
    })
  }
}
