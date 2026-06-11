import { COLORS } from '../constants/AppConstants'
import { SaveStatus } from '../models/GraphModels'

@Component
export struct HeaderBar {
  @Prop saveStatus: SaveStatus = 'saved'
  onImport: () => void = () => {}
  onExport: () => void = () => {}

  private getStatusText(): string {
    if (this.saveStatus === 'saving') {
      return '保存中...'
    } else if (this.saveStatus === 'failed') {
      return '保存失败'
    }
    return ''
  }

  build() {
    Row() {
      Text('WordNet Pro')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)

      if (this.getStatusText().length > 0) {
        Text(this.getStatusText())
          .fontSize(11)
          .fontColor(this.saveStatus === 'failed' ? COLORS.danger : COLORS.textSecondary)
          .margin({ left: 8 })
      }

      Blank()

      Button('导入')
        .type(ButtonType.Normal)
        .fontSize(13)
        .height(32)
        .borderRadius(6)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textPrimary)
        .border({ width: 1, color: COLORS.panelBorder })
        .margin({ right: 8 })
        .onClick(() => {
          this.onImport()
        })

      Button('保存')
        .type(ButtonType.Normal)
        .fontSize(13)
        .height(32)
        .borderRadius(6)
        .backgroundColor(COLORS.primary)
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.onExport()
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .backgroundColor(COLORS.panelBg)
    .border({ width: { bottom: 1 }, color: COLORS.panelBorder })
    .alignItems(VerticalAlign.Center)
  }
}
