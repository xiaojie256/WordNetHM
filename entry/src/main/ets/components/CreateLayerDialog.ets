import { COLORS } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'

@CustomDialog
export struct CreateLayerDialog {
  controller: CustomDialogController
  onConfirm: (name: string) => void = (name: string) => {}
  @State inputName: string = '新图层'

  aboutToAppear(): void {
    this.inputName = '新图层'
  }

  private doConfirm(): void {
    const trimmed: string = this.inputName.trim()
    const finalName: string = trimmed.length > 0 ? trimmed : '新图层'
    this.onConfirm(finalName)
    this.controller.close()
  }

  build() {
    Column({ space: 12 }) {
      Text('新建图层')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)

      TextInput({ text: this.inputName, placeholder: '请输入图层名称' })
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

        Button('创建')
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
