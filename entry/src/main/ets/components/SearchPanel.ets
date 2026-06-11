import { SearchResult } from '../models/GraphModels'
import { COLORS } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'

@Component
export struct SearchPanel {
  @State searchText: string = ''
  @State results: SearchResult[] = []
  onSearch: (keyword: string) => SearchResult[] = (keyword: string) => { return [] }
  onLocateNode: (nodeId: string) => void = (nodeId: string) => {}

  private handleSearch(): void {
    const trimmed: string = this.searchText.trim()
    if (trimmed.length === 0) {
      return
    }
    this.results = this.onSearch(trimmed)
    if (this.results.length === 0) {
      showToast('未找到匹配节点')
    } else {
      this.onLocateNode(this.results[0].nodeId)
    }
  }

  build() {
    Column() {
      Text('搜索定位')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textPrimary)
        .margin({ bottom: 12 })

      Row({ space: 8 }) {
        TextInput({ text: this.searchText, placeholder: '搜索当前图层节点' })
          .fontSize(14)
          .height(36)
          .borderRadius(8)
          .backgroundColor('#F8FAFC')
          .layoutWeight(1)
          .onChange((value: string) => {
            this.searchText = value
          })
          .onSubmit(() => {
            this.handleSearch()
          })

        Button('搜索')
          .type(ButtonType.Normal)
          .fontSize(13)
          .height(36)
          .borderRadius(8)
          .backgroundColor(COLORS.primary)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.handleSearch()
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      if (this.results.length > 0) {
        List({ space: 4 }) {
          ForEach(this.results, (result: SearchResult) => {
            ListItem() {
              Row() {
                Text(result.label)
                  .fontSize(13)
                  .fontColor(COLORS.textPrimary)
                  .layoutWeight(1)

                Text(result.score === 100 ? '完全匹配' : result.score === 80 ? '前缀匹配' : '包含匹配')
                  .fontSize(11)
                  .fontColor(COLORS.textSecondary)
              }
              .width('100%')
              .height(32)
              .padding({ left: 8, right: 8 })
              .borderRadius(6)
              .backgroundColor('#F1F5F9')
              .onClick(() => {
                this.onLocateNode(result.nodeId)
              })
            }
          })
        }
        .width('100%')
        .constraintSize({ maxHeight: 200 })
      }
    }
    .width('100%')
    .padding(12)
  }
}
