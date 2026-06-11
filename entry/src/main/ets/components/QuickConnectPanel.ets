import { WordNode } from '../models/GraphModels'
import { COLORS } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'

@Component
export struct QuickConnectPanel {
  @State sourceId: string = ''
  @State targetId: string = ''
  @Prop nodeLabels: string[] = []
  @Prop nodeIds: string[] = []
  onConnect: (sourceId: string, targetId: string) => void = (s: string, t: string) => {}
  onDisconnect: (sourceId: string, targetId: string) => void = (s: string, t: string) => {}

  private getSourceLabel(): string {
    const idx: number = this.nodeIds.indexOf(this.sourceId)
    return idx >= 0 ? this.nodeLabels[idx] : '请选择起始节点'
  }

  private getTargetLabel(): string {
    const idx: number = this.nodeIds.indexOf(this.targetId)
    return idx >= 0 ? this.nodeLabels[idx] : '请选择目标节点'
  }

  build() {
    Column() {
      Text('快速连接')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)
        .margin({ bottom: 12 })

      Text('起始节点')
        .fontSize(12)
        .fontColor(COLORS.textSecondary)
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Select(this.nodeLabels.map((label: string, index: number) => {
        return { value: label } as SelectOption
      }))
        .selected(this.nodeIds.indexOf(this.sourceId) >= 0 ? this.nodeIds.indexOf(this.sourceId) : 0)
        .value(this.getSourceLabel())
        .fontSize(13)
        .width('100%')
        .height(36)
        .margin({ bottom: 8 })
        .onSelect((index: number) => {
          if (index >= 0 && index < this.nodeIds.length) {
            this.sourceId = this.nodeIds[index]
          }
        })

      Text('目标节点')
        .fontSize(12)
        .fontColor(COLORS.textSecondary)
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      Select(this.nodeLabels.map((label: string, index: number) => {
        return { value: label } as SelectOption
      }))
        .selected(this.nodeIds.indexOf(this.targetId) >= 0 ? this.nodeIds.indexOf(this.targetId) : 0)
        .value(this.getTargetLabel())
        .fontSize(13)
        .width('100%')
        .height(36)
        .margin({ bottom: 12 })
        .onSelect((index: number) => {
          if (index >= 0 && index < this.nodeIds.length) {
            this.targetId = this.nodeIds[index]
          }
        })

      Row({ space: 8 }) {
        Button('连接')
          .type(ButtonType.Normal)
          .fontSize(13)
          .height(32)
          .borderRadius(6)
          .backgroundColor(COLORS.primary)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .onClick(() => {
            if (this.sourceId.length === 0 || this.targetId.length === 0) {
              showToast('请选择两个节点')
              return
            }
            if (this.sourceId === this.targetId) {
              showToast('不能连接同一个节点')
              return
            }
            this.onConnect(this.sourceId, this.targetId)
          })

        Button('断开')
          .type(ButtonType.Normal)
          .fontSize(13)
          .height(32)
          .borderRadius(6)
          .backgroundColor('#FEE2E2')
          .fontColor(COLORS.danger)
          .layoutWeight(1)
          .onClick(() => {
            if (this.sourceId.length === 0 || this.targetId.length === 0) {
              showToast('请选择两个节点')
              return
            }
            if (this.sourceId === this.targetId) {
              showToast('不能连接同一个节点')
              return
            }
            this.onDisconnect(this.sourceId, this.targetId)
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
  }
}
