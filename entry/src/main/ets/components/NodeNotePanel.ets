import { COLORS } from '../constants/AppConstants'
import { promptAction } from '@kit.ArkUI'
import { showToast } from '../utils/ToastUtil'

@Component
export struct NodeNotePanel {
  @Prop selectedNodeIds: string[] = []
  @Prop selectedNodeLabel: string = ''
  @State noteText: string = ''
  @Prop nodeId: string = ''
  onUpdateNote: (nodeId: string, note: string) => void = (id: string, note: string) => {}
  onRenameNode: (nodeId: string, newLabel: string) => void = (id: string, label: string) => {}
  onStartConnect: (nodeId: string) => void = (id: string) => {}
  onDeleteNode: (nodeId: string) => void = (id: string) => {}

  aboutToAppear(): void {
    this.noteText = ''
  }

  private handleNoteSave(): void {
    if (this.nodeId.length > 0) {
      this.onUpdateNote(this.nodeId, this.noteText)
    }
  }

  private showRenameDialog(): void {
    promptAction.showDialog({
      title: '重命名节点',
      message: `当前名称: ${this.selectedNodeLabel}`,
      buttons: [
        { text: '取消', color: COLORS.textSecondary },
        { text: '确认', color: COLORS.primary }
      ]
    }).then(() => {})
  }

  build() {
    Column() {
      Text('节点注释')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)
        .margin({ bottom: 12 })

      if (this.selectedNodeIds.length === 0) {
        Text('请选择一个节点以编辑注释。')
          .fontSize(13)
          .fontColor(COLORS.textSecondary)
          .margin({ top: 20 })
      } else if (this.selectedNodeIds.length === 1) {
        Text(this.selectedNodeLabel)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLORS.textPrimary)
          .margin({ bottom: 8 })

        TextArea({ text: this.noteText, placeholder: '暂无注释，可在此记录释义、例句或记忆方法。' })
          .fontSize(13)
          .height(120)
          .borderRadius(8)
          .backgroundColor('#F8FAFC')
          .margin({ bottom: 8 })
          .onChange((value: string) => {
            this.noteText = value
          })
          .onBlur(() => {
            this.handleNoteSave()
          })

        Row({ space: 6 }) {
          Button('重命名')
            .type(ButtonType.Normal)
            .fontSize(12)
            .height(28)
            .borderRadius(6)
            .backgroundColor(COLORS.primaryLight)
            .fontColor(COLORS.primary)
            .onClick(() => {
              this.showRenameDialog()
            })

          Button('建立连接')
            .type(ButtonType.Normal)
            .fontSize(12)
            .height(28)
            .borderRadius(6)
            .backgroundColor(COLORS.primaryLight)
            .fontColor(COLORS.primary)
            .onClick(() => {
              if (this.nodeId.length > 0) {
                this.onStartConnect(this.nodeId)
              }
            })

          Button('删除节点')
            .type(ButtonType.Normal)
            .fontSize(12)
            .height(28)
            .borderRadius(6)
            .backgroundColor('#FEE2E2')
            .fontColor(COLORS.danger)
            .onClick(() => {
              if (this.nodeId.length > 0) {
                this.onDeleteNode(this.nodeId)
              }
            })
        }
        .width('100%')
      } else {
        Text(`已选 ${this.selectedNodeIds.length} 个节点`)
          .fontSize(13)
          .fontColor(COLORS.textSecondary)
          .margin({ top: 20 })
      }
    }
    .width('100%')
    .padding(12)
  }
}
