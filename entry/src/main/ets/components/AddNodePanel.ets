import { COLORS } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'

@Component
export struct AddNodePanel {
  @State inputText: string = ''
  onAddNode: (label: string) => void = (label: string) => {}

  private handleAdd(): void {
    const trimmed: string = this.inputText.trim()
    if (trimmed.length === 0) {
      showToast('请输入单词')
      return
    }
    this.onAddNode(trimmed)
    this.inputText = ''
    showToast('添加成功')
  }

  build() {
    Column() {
      Text('添加单词')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)
        .margin({ bottom: 12 })

      TextInput({ text: this.inputText, placeholder: '输入单词、短语或概念' })
        .fontSize(14)
        .height(40)
        .borderRadius(8)
        .backgroundColor('#F8FAFC')
        .margin({ bottom: 8 })
        .onChange((value: string) => {
          this.inputText = value
        })
        .onSubmit(() => {
          this.handleAdd()
        })

      Button('添加')
        .type(ButtonType.Normal)
        .width('100%')
        .height(36)
        .fontSize(14)
        .borderRadius(8)
        .backgroundColor(COLORS.primary)
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.handleAdd()
        })
    }
    .width('100%')
    .padding(12)
  }
}
