import { WordNetSettings } from '../models/GraphModels'
import { COLORS } from '../constants/AppConstants'
import { promptAction } from '@kit.ArkUI'

@Component
export struct SettingsPanel {
  @Prop settings: WordNetSettings = {
    autoSave: true,
    showGrid: false,
    defaultZoom: 1,
    confirmBeforeDelete: true,
    confirmBeforeClear: true
  }
  onUpdateSettings: (settings: WordNetSettings) => void = (s: WordNetSettings) => {}
  onClearAllData: () => void = () => {}
  onClose: () => void = () => {}

  private showClearConfirm(): void {
    promptAction.showDialog({
      title: '确认清空',
      message: '确定清空所有数据吗？该操作会删除全部图层、节点、连接和注释，且无法恢复。',
      buttons: [
        { text: '取消', color: COLORS.textSecondary },
        { text: '确认清空', color: COLORS.danger }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.onClearAllData()
      }
    })
  }

  private buildSettings(autoSave: boolean, showGrid: boolean): WordNetSettings {
    const result: WordNetSettings = {
      autoSave: autoSave,
      showGrid: showGrid,
      defaultZoom: this.settings.defaultZoom,
      confirmBeforeDelete: this.settings.confirmBeforeDelete,
      confirmBeforeClear: this.settings.confirmBeforeClear
    }
    return result
  }

  build() {
    Column() {
      Row() {
        Text('设置')
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
      .margin({ bottom: 16 })

      Row() {
        Text('自动保存')
          .fontSize(14)
          .fontColor(COLORS.textPrimary)
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.settings.autoSave })
          .onChange((isOn: boolean) => {
            this.onUpdateSettings(this.buildSettings(isOn, this.settings.showGrid))
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: 4, right: 4 })

      Row() {
        Text('显示网格')
          .fontSize(14)
          .fontColor(COLORS.textPrimary)
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.settings.showGrid })
          .onChange((isOn: boolean) => {
            this.onUpdateSettings(this.buildSettings(this.settings.autoSave, isOn))
          })
      }
      .width('100%')
      .height(44)
      .padding({ left: 4, right: 4 })

      Divider()
        .margin({ top: 12, bottom: 12 })

      Button('清空所有数据')
        .type(ButtonType.Normal)
        .width('100%')
        .height(40)
        .fontSize(14)
        