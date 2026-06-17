import { COLORS } from '../constants/AppConstants'

@CustomDialog
export struct EditNoteDialog {
  controller: CustomDialogController

  nodeName: string = ''
  currentNote: string = ''
  onConfirm: (note: string) => void = () => {}

  @State inputNote: string = ''

  aboutToAppear(): void {
    this.inputNote = this.currentNote
  }

  private doConfirm(): void {
    this.onConfirm(this.inputNote)
    this.controller.close()
  }

  build() {
    Column({ space: 12 }) {
      Text('编辑注释')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)

      Text(this.nodeName.length > 0 ? '节点：' + this.nodeName : '节点注释')
        .fontSize(13)
        .fontColor(COLORS.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      TextArea({
        text: this.inputNote,
        placeholder: '请输入节点注释；内容过长时可在输入框内上下滑动查看'
      })
        .width('100%')
        .height(260)
        .fontSize(14)
        .borderRadius(8)
        .backgroundColor('#F8FAFC')
        .padding(10)
        .onChange((value: string) => {
          this.inputNote = value
        })

      Text('提示：长注释已使用固定高度多行输入框，内容过长时可在输入框内上下滑动查看全部内容。')
        .fontSize(12)
        .fontColor(COLORS.textSecondary)

      Row({ space: 8 }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .borderRadius(8)
          .backgroundColor('#E5E7EB')
          .fontColor('#374151')
          .onClick(() => {
            this.controller.close()
          })

        Button('保存')
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .borderRadius(8)
          .backgroundColor(COLORS.primary)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.doConfirm()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
  }
}
