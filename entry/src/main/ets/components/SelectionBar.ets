import { COLORS, LARGE_CONNECTION_CONFIRM_THRESHOLD } from '../constants/AppConstants'

@Component
export struct SelectionBar {
  @Prop selectedCount: number = 0
  onConnectAll: () => void = () => {}
  onDisconnectSelected: () => void = () => {}
  onDeleteSelected: () => void = () => {}
  onCancel: () => void = () => {}

  build() {
    Row() {
      Text(`已选 ${this.selectedCount} 个`)
        .fontSize(14)
        .fontColor(COLORS.textPrimary)
        .margin({ right: 12 })

      Button('全部连接')
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(30)
        .borderRadius(6)
        .backgroundColor(COLORS.primaryLight)
        .fontColor(COLORS.primary)
        .enabled(this.selectedCount >= 2)
        .opacity(this.selectedCount >= 2 ? 1 : 0.5)
        .margin({ right: 6 })
        .onClick(() => {
          this.onConnectAll()
        })

      Button('断开选中')
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(30)
        .borderRadius(6)
        .backgroundColor(COLORS.primaryLight)
        .fontColor(COLORS.primary)
        .enabled(this.selectedCount >= 2)
        .opacity(this.selectedCount >= 2 ? 1 : 0.5)
        .margin({ right: 6 })
        .onClick(() => {
          this.onDisconnectSelected()
        })

      Button('删除')
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(30)
        .borderRadius(6)
        .backgroundColor('#FEE2E2')
        .fontColor(COLORS.danger)
        .margin({ right: 6 })
        .onClick(() => {
          this.onDeleteSelected()
        })

      Button('取消')
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(30)
        .borderRadius(6)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textSecondary)
        .onClick(() => {
          this.onCancel()
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(COLORS.panelBg)
    .border({ width: { top: 1 }, color: COLORS.panelBorder })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
