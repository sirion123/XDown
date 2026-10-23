// AccountRow - 平台账号行（独立组件，保证登录状态变化时能刷新）
@Component
export struct AccountRow {
  @Prop name: string = ''
  @Prop initial: string = ''
  @Prop loggedIn: boolean = false
  onLogin?: () => void
  onLogout?: () => void

  build() {
    Row() {
      Stack() {
        Circle()
          .width(36)
          .height(36)
          .fill($r('app.color.chip_bg'))

        Text(this.initial)
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }

      Column() {
        Text(this.name)
          .fontSize($r('app.float.font_body_small'))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)

        Text(this.loggedIn ? '已登录' : '未登录')
          .fontSize($r('app.float.font_caption'))
          .fontColor(this.loggedIn ? $r('app.color.status_success') : $r('app.color.text_tertiary'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      Button(this.loggedIn ? '退出' : '登录')
        .type(ButtonType.Capsule)
        .controlSize(ControlSize.SMALL)
        .height(30)
        .fontSize($r('app.float.font_caption'))
        .buttonStyle(this.loggedIn ? ButtonStyleMode.NORMAL : ButtonStyleMode.EMPHASIZED)
        .onClick(() => {
          if (this.loggedIn) {
            if (this.onLogout) {
              this.onLogout()
            }
          } else {
            if (this.onLogin) {
              this.onLogin()
            }
          }
        })
    }
    .width('100%')
  }
}
