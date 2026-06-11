import { COLORS } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'

@CustomDialog
export struct RenameNodeDialog {
  controller: CustomDialogController
  currentName: string = ''
  onConfirm: (newName: string) => void = (name: string) => {}
  @State inputName: string = ''

  aboutToAppear(): void {
    this.inputName = this.currentName
  }

  private doConfirm(): void {
    const trimmed: string = this.inputName.trim()
    if (trimmed.length === 0) {
      showToast('名称不能为空')
      return
    }
    this.onConfirm(trimmed)
    this.controller.close()
  }

  build() {
    Column({ space: 12 }) {
      Text('重命名节点')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)

      TextInput({ text: this.inputName, placeholder: '请输入节点名称' })
        .height(44)
        .fontSize(15)
        .borderRadius(8)
        .backgroundColor('#F8FAFC')
        .padding({ left: 10, right: 10 })
        .onChange((value: string) => {
          this.inputName = value
        })
        .onSubmit(() => {
          this.doConfirm()
        })

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

        Button('确认')
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
