import { JsonDialogMode } from '../models/GraphModels'
import { COLORS } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'
import { promptAction } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'

@Component
export struct JsonDialog {
  @Prop mode: JsonDialogMode = 'export'
  @State jsonText: string = ''
  onImport: (jsonText: string) => void = (text: string) => {}
  onClose: () => void = () => {}

  private handleImport(): void {
    const trimmed: string = this.jsonText.trim()
    if (trimmed.length === 0) {
      showToast('请粘贴 JSON 数据')
      return
    }

    promptAction.showDialog({
      title: '确认导入',
      message: '导入会覆盖当前所有数据，是否继续？',
      buttons: [
        { text: '取消', color: COLORS.textSecondary },
        { text: '确认导入', color: COLORS.danger }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.onImport(trimmed)
      }
    })
  }

  private async handleCopy(): Promise<void> {
    try {
      const pasteboardData: pasteboard.Data = {
        mimeType: pasteboard.MIMETYPE.TEXT_PLAIN,
        data: this.jsonText
      }
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard()
      await systemPasteboard.setData(pasteboardData)
      showToast('已复制到剪贴板')
    } catch (err) {
      showToast('复制失败，请长按文本手动复制')
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.mode === 'export' ? '导出 JSON' : '导入 JSON')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.textPrimary)

        Blank()

        Button('关闭')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(28)
          .borderRadius(6)
          .backgroundColor('#F1F5F9')
          .fontColor(COLORS.textSecondary)
          .onClick(() => {
            this.onClose()
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.mode === 'export') {
        TextArea({ text: this.jsonText })
          .fontSize(12)
          .height(300)
          .borderRadius(8)
          .backgroundColor('#F8FAFC')
          .enabled(false)
          .margin({ bottom: 12 })

        Row({ space: 8 }) {
          Button('复制')
            .type(ButtonType.Normal)
            .fontSize(13)
            .height(36)
            .borderRadius(8)
            .backgroundColor(COLORS.primary)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .onClick(() => {
              this.handleCopy()
            })

          Button('关闭')
            .type(ButtonType.Normal)
            .fontSize(13)
            .height(36)
            .borderRadius(8)
            .backgroundColor(COLORS.panelBg)
            .fontColor(COLORS.textPrimary)
            .layoutWeight(1)
            .onClick(() => {
              this.onClose()
            })
        }
        .width('100%')
      } else {
        TextArea({ text: this.jsonText, placeholder: '请粘贴 Workspace JSON 数据' })
          .fontSize(12)
          .height(300)
          .borderRadius(8)
          .backgroundColor('#F8FAFC')
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.jsonText = value
          })

        Row({ space: 8 }) {
          Button('确认导入')
            .type(ButtonType.Normal)
            .fontSize(13)
            .height(36)
            .borderRadius(8)
            .backgroundColor(COLORS.danger)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .onClick(() => {
              this.handleImport()
            })

          Button('取消')
            .type(ButtonType.Normal)
            .fontSize(13)
            .height(36)
            .borderRadius(8)
            .backgroundColor(COLORS.panelBg)
            .fontColor(COLORS.textPrimary)
            .layoutWeight(1)
            .onClick(() => {
              this.onClose()
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
  }
}
