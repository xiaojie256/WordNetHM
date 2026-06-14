import { COLORS } from '../constants/AppConstants'

@Component
export struct ContextMenu {
  @Prop visible: boolean = false
  @Prop menuX: number = 0
  @Prop menuY: number = 0
  onConnect: () => void = () => {}
  onEditNote: () => void = () => {}
  onRename: () => void = () => {}
  onDelete: () => void = () => {}
  onClose: () => void = () => {}

  build() {
    if (this.visible) {
      Column({ space: 2 }) {
        Button('建立连接')
          .type(ButtonType.Normal)
          .width(130)
          .height(40)
          .fontSize(14)
          .borderRadius(0)
          .backgroundColor(COLORS.panelBg)
          .fontColor(COLORS.textPrimary)
          .onClick(() => {
            this.onConnect()
          })

        Button('编辑注释')
          .type(ButtonType.Normal)
          .width(130)
          .height(40)
          .fontSize(14)
          .borderRadius(0)
          .backgroundColor(COLORS.panelBg)
          .fontColor(COLORS.textPrimary)
          .onClick(() => {
            this.onEditNote()
          })

        Button('重命名')
          .type(ButtonType.Normal)
          .width(130)
          .height(40)
          .fontSize(14)
          .borderRadius(0)
          .backgroundColor(COLORS.panelBg)
          .fontColor(COLORS.textPrimary)
          .onClick(() => {
            this.onRename()
          })

        Button('删除节点')
          .type(ButtonType.Normal)
          .width(130)
          .height(40)
          .fontSize(14)
          .borderRadius(0)
          .backgroundColor(COLORS.panelBg)
          .fontColor(COLORS.danger)
          .onClick(() => {
            this.onDelete()
          })
      }
      .position({ x: this.menuX, y: this.menuY })
      .borderRadius(8)
      .shadow({ radius: 8, color: '#33000000' })
      .clip(true)
      .zIndex(999)
    }
  }
}
