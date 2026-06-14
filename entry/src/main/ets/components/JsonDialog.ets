import { JsonDialogMode } from '../models/GraphModels'
import { COLORS } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'
import { promptAction } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'

@Component
export struct JsonDialog {
  @Prop mode: JsonDialogMode = 'export'
  @Prop jsonText: string = ''
  @State importText: string = ''
  onImport: (jsonText: string) => void = (text: string) => {}
  onClose: () => void = () => {}

  private async copyToClipboard(): Promise<void> {
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.jsonText)
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard()
      await systemPasteboard.setData(pasteData)
      showToast('已复制到剪贴板')
    } catch (err) {
      showToast('复制失败')
    }
  }

  private handleImport(): void {
    const trimmed: string = this.importText.trim()
    if (trimmed.length === 0) {
      showToast('请粘贴 JSON 数据')
      return
    }
    try {
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
    } catch (err) {
      showToast('操作失败')
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.mode === 'export' ? '导出 JSON' : '导入 JSON')
          .fontSize(18)
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
        Scroll() {
          Text(this.jsonText)
            .fontSize(12)
            .fontColor(COLORS.textPrimary)
            .width('100%')
            .padding(8)
            .copyOption(CopyOptions.InApp)
        }
        .width('100%')
        .layoutWeight(1)
        .borderRadius(8)
        .backgroundColor('#F8FAFC')
        .margin({ bottom: 12 })

        Row({ space: 8 }) {
          Button('复制全部')
            .type(ButtonType.Normal)
            .fontSize(13)
            .height(40)
            .borderRadius(8)
            .backgroundColor(COLORS.primary)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .onClick(() => {
              this.copyToClipboard()
            })

          Button('关闭')
            .type(ButtonType.Normal)
            .fontSize(13)
            .height(40)
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
        Scroll() {
          TextArea({ text: this.importText, placeholder: '请粘贴 Workspace JSON 数据' })
            .fontSize(12)
            .width('100%')
            .borderRadius(8)
            .backgroundColor('#F8FAFC')
            .onChange((value: string) => {
              this.importText = value
            })
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ bottom: 12 })

        Row({ space: 8 }) {
          Button('确认导入')
            .type(ButtonType.Normal)
            .fontSize(13)
            .height(40)
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
            .height(40)
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
    .height('100%')
    .padding(16)
  }
}
