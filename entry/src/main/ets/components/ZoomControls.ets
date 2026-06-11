import { COLORS } from '../constants/AppConstants'

@Component
export struct ZoomControls {
  @Prop cameraScale: number = 1
  @Prop hasSelectedNode: boolean = false
  @Prop boxSelectMode: boolean = false
  onZoomIn: () => void = () => {}
  onZoomOut: () => void = () => {}
  onReset: () => void = () => {}
  onFit: () => void = () => {}
  onAction: () => void = () => {}
  onToggleBoxSelect: () => void = () => {}

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.boxSelectMode ? '退出' : '框选')
          .fontSize(13)
          .fontColor(this.boxSelectMode ? '#FFFFFF' : COLORS.primary)
          .fontWeight(FontWeight.Medium)
      }
      .width(56)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.boxSelectMode ? COLORS.primary : COLORS.primaryLight)
      .borderRadius(10)
      .onClick(() => {
        this.onToggleBoxSelect()
      })

      Row() {
        Text('操作')
          .fontSize(13)
          .fontColor(this.hasSelectedNode ? '#FFFFFF' : '#9CA3AF')
          .fontWeight(FontWeight.Medium)
      }
      .width(56)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.hasSelectedNode ? COLORS.primary : '#E5E7EB')
      .borderRadius(10)
      .onClick(() => {
        this.onAction()
      })

      Button('+')
        .type(ButtonType.Circle)
        .width(48)
        .height(48)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textPrimary)
        .shadow({ radius: 6, color: '#22000000' })
        .onClick(() => {
          this.onZoomIn()
        })

      Button('−')
        .type(ButtonType.Circle)
        .width(48)
        .height(48)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textPrimary)
        .shadow({ radius: 6, color: '#22000000' })
        .onClick(() => {
          this.onZoomOut()
        })

      Button('1:1')
        .type(ButtonType.Normal)
        .width(48)
        .height(40)
        .fontSize(11)
        .borderRadius(20)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textPrimary)
        .shadow({ radius: 6, color: '#22000000' })
        .onClick(() => {
          this.onReset()
        })

      Button('◎')
        .type(ButtonType.Normal)
        .width(48)
        .height(40)
        .fontSize(16)
        .borderRadius(20)
        .backgroundColor(COLORS.panelBg)
        .fontColor(COLORS.textPrimary)
        .shadow({ radius: 6, color: '#22000000' })
        .onClick(() => {
          this.onFit()
        })
    }
    .margin({ right: 16, bottom: 120 })
  }
}
