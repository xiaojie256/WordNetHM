import { SaveStatus } from '../models/GraphModels'
import { COLORS } from '../constants/AppConstants'

@Component
export struct TopBar {
  @Prop saveStatus: SaveStatus = 'saved'
  onImport: () => void = () => {}
  onSave: () => void = () => {}
  onExport: () => void = () => {}
  onOpenSettings: () => void = () => {}

  private getStatusText(): string {
    if (this.saveStatus === 'saving') {
      return '保存中'
    } else if (this.saveStatus === 'failed') {
      return '保存失败'
    }
    return '已保存'
  }

  private getStatusColor(): ResourceColor {
    if (this.saveStatus === 'failed') {
      return COLORS.danger
    } else if (this.saveStatus === 'saving') {
      return COLORS.warning
    }
    return COLORS.textSecondary
  }

  build() {
    Row() {
      Text('WordNet Pro')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)
        .margin({ right: 8 })

      Text(this.getStatusText())
        .fontSize(12)
        .fontColor(this.getStatusColor())
        .margin({ right: 'auto' })

      Button('导入')
        .type(ButtonType.Normal)
        .fontSize(13)
        .height(32)
        .borderRadius(6)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textPrimary)
        .margin({ right: 6 })
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
        .margin({ right: 6 })
        .onClick(() => {
          this.onSave()
        })

      Button('导出')
        .type(ButtonType.Normal)
        .fontSize(13)
        .height(32)
        .borderRadius(6)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textPrimary)
        .margin({ right: 6 })
        .onClick(() => {
          this.onExport()
        })

      Button('设置')
        .type(ButtonType.Normal)
        .fontSize(13)
        .height(32)
        .borderRadius(6)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textPrimary)
        .onClick(() => {
          this.onOpenSettings()
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(COLORS.panelBg)
    .border({ width: { bottom: 1 }, color: COLORS.panelBorder })
    .alignItems(VerticalAlign.Center)
  }
}
