import { Layer } from '../models/GraphModels'
import { COLORS } from '../constants/AppConstants'
import { promptAction } from '@kit.ArkUI'

@Component
export struct LayerPanel {
  @Prop layerNames: string[] = []
  @Prop layerIds: string[] = []
  @Prop activeLayerId: string = ''
  onCreateLayer: () => void = () => {}
  onCopyLayer: () => void = () => {}
  onRenameLayer: (name: string) => void = (name: string) => {}
  onSwitchLayer: (layerId: string) => void = (layerId: string) => {}

  private showRenameDialog(): void {
    const currentName: string = (() => {
      const idx: number = this.layerIds.indexOf(this.activeLayerId)
      return idx >= 0 ? this.layerNames[idx] : ''
    })()

    promptAction.showDialog({
      title: '重命名图层',
      message: '请输入新名称',
      buttons: [
        { text: '取消', color: COLORS.textSecondary },
        { text: '确认', color: COLORS.primary }
      ]
    }).then(() => {})
  }

  build() {
    Column() {
      Text('图层管理')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)
        .margin({ bottom: 12 })

      List({ space: 4 }) {
        ForEach(this.layerIds, (layerId: string, index: number) => {
          ListItem() {
            Row() {
              Text(this.layerNames[index] ?? '')
                .fontSize(13)
                .fontColor(COLORS.textPrimary)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (layerId === this.activeLayerId) {
                Text('✓')
                  .fontSize(14)
                  .fontColor(COLORS.primary)
              }
            }
            .width('100%')
            .height(36)
            .padding({ left: 8, right: 8 })
            .borderRadius(6)
            .backgroundColor(layerId === this.activeLayerId ? COLORS.primaryLight : '#F1F5F9')
            .onClick(() => {
              this.onSwitchLayer(layerId)
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)

      Row({ space: 8 }) {
        Button('新建')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(30)
          .borderRadius(6)
          .backgroundColor(COLORS.primaryLight)
          .fontColor(COLORS.primary)
          .layoutWeight(1)
          .onClick(() => {
            this.onCreateLayer()
          })

        Button('复制')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(30)
          .borderRadius(6)
          .backgroundColor(COLORS.primaryLight)
          .fontColor(COLORS.primary)
          .layoutWeight(1)
          .onClick(() => {
            this.onCopyLayer()
          })

        Button('重命名')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(30)
          .borderRadius(6)
          .backgroundColor(COLORS.primaryLight)
          .fontColor(COLORS.primary)
          .layoutWeight(1)
          .onClick(() => {
            this.showRenameDialog()
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
  }
}
