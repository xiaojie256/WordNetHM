import { WorkspaceData, WordLayer, WordNode, WordEdge, CameraState } from '../models/GraphModels'
import { COLORS } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'
import { createDefaultWorkspace } from '../services/WorkspaceFactory'
import { promptAction } from '@kit.ArkUI'

interface Point2D {
  x: number
  y: number
}

@Component
export struct ControlPanel {
  @Prop workspace: WorkspaceData = createDefaultWorkspace()
  @Prop boxSelectMode: boolean = false
  @Prop selectedNodeId: number = -1
  @State inputWord: string = ''
  @State searchText: string = ''
  @State searchResults: WordNode[] = []
  @State selectedSourceIndex: number = -1
  @State selectedTargetIndex: number = -1
  @State sourceSearchText: string = ''
  @State targetSearchText: string = ''
  @State sourceSuggestions: WordNode[] = []
  @State targetSuggestions: WordNode[] = []
  onWorkspaceChange: (ws: WorkspaceData) => void = (ws: WorkspaceData) => {}
  onClose: () => void = () => {}
  onLocateNode: (nodeId: number) => void = (id: number) => {}
  onRenameLayerRequest: () => void = () => {}
  onCreateLayerRequest: () => void = () => {}
  onDeleteLayer: (layerId: string) => void = (layerId: string) => {}
  onToggleBoxSelectMode: () => void = () => {}
  @Prop alphabetSorted: boolean = false
  onToggleAlphabetSort: () => void = () => {}

  private getCurrentLayer(): WordLayer | undefined {
    for (const l of this.workspace.layers) {
      if (l.id === this.workspace.currentLayerId) {
        return l
      }
    }
    return undefined
  }

  private emit(ws: WorkspaceData): void {
    ws.updatedAt = Date.now()
    this.onWorkspaceChange(ws)
  }

  private addWord(): void {
    const word: string = this.inputWord.trim()
    if (word.length === 0) {
      showToast('请输入单词')
      return
    }
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    for (const n of layer.nodes) {
      if (n.word === word) {
        showToast('已存在')
        return
      }
    }
    const newNode: WordNode = {
      id: layer.nextId,
      word: word,
      x: Math.random() * 60 - 30,
      y: Math.random() * 60 - 30,
      note: ''
    }
    const updatedNodes: WordNode[] = [...layer.nodes, newNode]
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: updatedNodes, edges: layer.edges,
      nextId: layer.nextId + 1, camera: layer.camera,
      createdAt: layer.createdAt, updatedAt: Date.now()
    }
    const updatedLayers: WordLayer[] = this.replaceLayer(updatedLayer)
    this.emit({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
    this.inputWord = ''
    showToast('添加成功')
  }

  private replaceLayer(updated: WordLayer): WordLayer[] {
    const result: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id === updated.id) {
        result.push(updated)
      } else {
        result.push(l)
      }
    }
    return result
  }

  private switchLayer(layerId: string): void {
    this.emit({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: layerId, layers: this.workspace.layers, updatedAt: Date.now()
    })
  }

  private createLayer(): void {
    this.onCreateLayerRequest()
  }

  private copyCurrentLayer(): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const id: string = 'layer_' + Date.now()
    const copiedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      copiedNodes.push({ id: n.id, word: n.word, x: n.x, y: n.y, note: n.note })
    }
    const copiedEdges: WordEdge[] = []
    for (const e of layer.edges) {
      const edge: WordEdge = { from: e.from, to: e.to }
      copiedEdges.push(edge)
    }
    const copiedCamera: CameraState = { x: layer.camera.x, y: layer.camera.y, scale: layer.camera.scale }
    const newLayer: WordLayer = {
      id: id, name: `${layer.name} 副本`, nodes: copiedNodes, edges: copiedEdges,
      nextId: layer.nextId, camera: copiedCamera,
      createdAt: Date.now(), updatedAt: Date.now()
    }
    const updatedLayers: WordLayer[] = [...this.workspace.layers, newLayer]
    this.emit({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: id, layers: updatedLayers, updatedAt: Date.now()
    })
  }

  private renameCurrentLayer(): void {
    this.onRenameLayerRequest()
  }

  private confirmDeleteLayer(layerId: string, layerName: string): void {
    if (this.workspace.layers.length <= 1) {
      showToast('至少保留一个图层')
      return
    }
    try {
      promptAction.showDialog({
        title: '删除图层',
        message: '确定删除图层"' + layerName + '"吗？',
        buttons: [
          { text: '取消', color: COLORS.textSecondary },
          { text: '删除', color: COLORS.danger }
        ]
      }).then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) {
          this.onDeleteLayer(layerId)
        }
      })
    } catch (err) {
      showToast('操作失败')
    }
  }

  private doSearch(): void {
    const keyword: string = this.searchText.trim().toLowerCase()
    if (keyword.length === 0) {
      this.searchResults = []
      return
    }
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      this.searchResults = []
      return
    }
    const results: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.word.toLowerCase().includes(keyword) || n.note.toLowerCase().includes(keyword)) {
        results.push(n)
      }
    }
    this.searchResults = results
    if (results.length > 0) {
      this.onLocateNode(results[0].id)
    } else {
      showToast('未找到')
    }
  }

  private filterSuggestions(): void {
    const keyword: string = this.searchText.trim().toLowerCase()
    if (keyword.length === 0) {
      this.searchResults = []
      return
    }
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      this.searchResults = []
      return
    }
    const results: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.word.toLowerCase().includes(keyword) || n.note.toLowerCase().includes(keyword)) {
        results.push(n)
        if (results.length >= 8) {
          break
        }
      }
    }
    this.searchResults = results
  }

  private connectNodes(): void {
    if (this.selectedSourceIndex < 0 || this.selectedTargetIndex < 0) {
      showToast('请选择两个节点')
      return
    }
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const source: WordNode | undefined = layer.nodes[this.selectedSourceIndex]
    const target: WordNode | undefined = layer.nodes[this.selectedTargetIndex]
    if (!source || !target) {
      return
    }
    if (source.id === target.id) {
      showToast('不能连接同一个节点')
      return
    }
    for (const e of layer.edges) {
      if ((e.from === source.id && e.to === target.id) || (e.from === target.id && e.to === source.id)) {
        showToast('连接已存在')
        return
      }
    }
    const newEdge: WordEdge = { from: source.id, to: target.id }
    const updatedEdges: WordEdge[] = [...layer.edges, newEdge]
    const updated: WordLayer = {
      id: layer.id, name: layer.name, nodes: layer.nodes, edges: updatedEdges,
      nextId: layer.nextId, camera: layer.camera,
      createdAt: layer.createdAt, updatedAt: Date.now()
    }
    this.emit({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: this.replaceLayer(updated), updatedAt: Date.now()
    })
    showToast('连接成功')
  }

  private disconnectNodes(): void {
    if (this.selectedSourceIndex < 0 || this.selectedTargetIndex < 0) {
      showToast('请选择两个节点')
      return
    }
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const source: WordNode | undefined = layer.nodes[this.selectedSourceIndex]
    const target: WordNode | undefined = layer.nodes[this.selectedTargetIndex]
    if (!source || !target) {
      return
    }
    const filtered: WordEdge[] = []
    for (const e of layer.edges) {
      if (!((e.from === source.id && e.to === target.id) || (e.from === target.id && e.to === source.id))) {
        filtered.push(e)
      }
    }
    const updated: WordLayer = {
      id: layer.id, name: layer.name, nodes: layer.nodes, edges: filtered,
      nextId: layer.nextId, camera: layer.camera,
      createdAt: layer.createdAt, updatedAt: Date.now()
    }
    this.emit({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: this.replaceLayer(updated), updatedAt: Date.now()
    })
    showToast('断开成功')
  }

  private clearAll(): void {
    try {
      promptAction.showDialog({
        title: '确认清空',
        message: '确定清空所有数据吗？',
        buttons: [
          { text: '取消', color: COLORS.textSecondary },
          { text: '确认清空', color: COLORS.danger }
        ]
      }).then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) {
          const defaultCamera: CameraState = { x: 0, y: 0, scale: 1 }
          const defaultLayer: WordLayer = {
            id: 'default', name: '默认图层', nodes: [], edges: [], nextId: 0,
            camera: defaultCamera, createdAt: Date.now(), updatedAt: Date.now()
          }
          const defaultWs: WorkspaceData = {
            version: '1.0.0', appName: 'WordNet Pro', currentLayerId: 'default',
            layers: [defaultLayer],
            updatedAt: Date.now()
          }
          this.onWorkspaceChange(defaultWs)
          showToast('已清空')
        }
      })
    } catch (err) {
      showToast('操作失败')
    }
  }

  @Builder
  LayerCard() {
    Column({ space: 8 }) {
      Text('图层管理')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textSecondary)

      if (this.workspace.layers.length > 0) {
        ForEach(this.workspace.layers, (layer: WordLayer) => {
          Row() {
            Text(layer.name)
              .fontSize(14)
              .fontColor(COLORS.textPrimary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (layer.id === this.workspace.currentLayerId) {
              Text('✓')
                .fontSize(14)
                .fontColor(COLORS.primary)
                .margin({ right: 4 })
            }

            if (this.workspace.layers.length > 1) {
              Row() {
                Text('删除')
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Medium)
              }
              .width(52)
              .height(28)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .backgroundColor(COLORS.danger)
              .borderRadius(8)
              .margin({ left: 8 })
              .onClick(() => {
                this.confirmDeleteLayer(layer.id, layer.name)
              })
            }
          }
          .width('100%')
          .height(40)
          .padding({ left: 10, right: 10 })
          .borderRadius(8)
          .backgroundColor(layer.id === this.workspace.currentLayerId ? COLORS.primaryLight : '#F1F5F9')
          .onClick(() => {
            this.switchLayer(layer.id)
          })
        })
      }

      Row({ space: 6 }) {
        Button('新建')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(36)
          .borderRadius(8)
          .backgroundColor(COLORS.primaryLight)
          .fontColor(COLORS.primary)
          .layoutWeight(1)
          .onClick(() => { this.createLayer() })

        Button('复制')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(36)
          .borderRadius(8)
          .backgroundColor(COLORS.primaryLight)
          .fontColor(COLORS.primary)
          .layoutWeight(1)
          .onClick(() => { this.copyCurrentLayer() })

        Button('重命名')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(36)
          .borderRadius(8)
          .backgroundColor(COLORS.primaryLight)
          .fontColor(COLORS.primary)
          .layoutWeight(1)
          .onClick(() => { this.renameCurrentLayer() })
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F8FAFC')
    .borderRadius(10)
  }

  @Builder
  AddWordCard() {
    Column({ space: 8 }) {
      Text('添加单词')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textSecondary)

      Row({ space: 6 }) {
        TextInput({ text: this.inputWord, placeholder: '输入单词...' })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
          .backgroundColor('#F8FAFC')
          .layoutWeight(1)
          .onChange((value: string) => { this.inputWord = value })
          .onSubmit(() => { this.addWord() })

        Button('添加')
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(40)
          .borderRadius(8)
          .backgroundColor(COLORS.primary)
          .fontColor('#FFFFFF')
          .onClick(() => { this.addWord() })
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F8FAFC')
    .borderRadius(10)
  }

  @Builder
  SearchCard() {
    Column({ space: 8 }) {
      Text('搜索定位')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textSecondary)

      Row({ space: 6 }) {
        TextInput({ text: this.searchText, placeholder: '搜索单词或注释...' })
          .fontSize(14)
          .height(40)
          .borderRadius(8)
          .backgroundColor('#F8FAFC')
          .layoutWeight(1)
          .onChange((value: string) => {
            this.searchText = value
            this.filterSuggestions()
          })
          .onSubmit(() => { this.doSearch() })

        Button('搜索')
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(40)
          .borderRadius(8)
          .backgroundColor(COLORS.primary)
          .fontColor('#FFFFFF')
          .onClick(() => { this.doSearch() })
      }
      .width('100%')

      if (this.searchResults.length > 0) {
        Column({ space: 4 }) {
          ForEach(this.searchResults, (node: WordNode) => {
            Row() {
              Text(node.word)
                .fontSize(13)
                .fontColor(COLORS.textPrimary)
                .layoutWeight(1)
            }
            .width('100%')
            .height(36)
            .padding({ left: 10, right: 10 })
            .borderRadius(6)
            .backgroundColor('#F1F5F9')
            .onClick(() => {
              this.searchText = node.word
              this.searchResults = []
              this.onLocateNode(node.id)
            })
          })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F8FAFC')
    .borderRadius(10)
  }

  @Builder
  QuickActionsCard() {
    Column({ space: 8 }) {
      Text('快捷操作')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textSecondary)

      Text('在上方工具栏使用框选和排序功能')
        .fontSize(12)
        .fontColor(COLORS.textSecondary)
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F8FAFC')
    .borderRadius(10)
  }

  @Builder
  ConnectCard() {
    Column({ space: 8 }) {
      Text('快速连接')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textSecondary)

      Text('起始节点')
        .fontSize(12)
        .fontColor(COLORS.textSecondary)

      Select(this.getNodeOptions())
        .selected(this.selectedSourceIndex >= 0 ? this.selectedSourceIndex : 0)
        .value(this.selectedSourceIndex >= 0 ? this.getNodeLabel(this.selectedSourceIndex) : '请选择')
        .width('100%')
        .height(40)
        .onSelect((index: number) => {
          this.selectedSourceIndex = index
          this.sourceSearchText = this.getNodeLabel(index)
          this.sourceSuggestions = []
        })

      TextInput({ text: this.sourceSearchText, placeholder: '输入字母快速查找起始节点...' })
        .fontSize(13)
        .height(36)
        .borderRadius(8)
        .backgroundColor('#FFFFFF')
        .onChange((value: string) => {
          this.sourceSearchText = value
          this.sourceSuggestions = this.getConnectionSuggestions(value)
        })

      if (this.sourceSuggestions.length > 0) {
        Column({ space: 4 }) {
          ForEach(this.sourceSuggestions, (node: WordNode) => {
            Row() {
              Text(node.word)
                .fontSize(13)
                .fontColor(COLORS.textPrimary)
                .layoutWeight(1)
            }
            .width('100%')
            .height(34)
            .padding({ left: 10, right: 10 })
            .borderRadius(6)
            .backgroundColor('#EEF2FF')
            .onClick(() => {
              this.selectSourceNode(node)
            })
          })
        }
        .width('100%')
      }

      Text('目标节点')
        .fontSize(12)
        .fontColor(COLORS.textSecondary)

      Select(this.getNodeOptions())
        .selected(this.selectedTargetIndex >= 0 ? this.selectedTargetIndex : 0)
        .value(this.selectedTargetIndex >= 0 ? this.getNodeLabel(this.selectedTargetIndex) : '请选择')
        .width('100%')
        .height(40)
        .onSelect((index: number) => {
          this.selectedTargetIndex = index
          this.targetSearchText = this.getNodeLabel(index)
          this.targetSuggestions = []
        })

      TextInput({ text: this.targetSearchText, placeholder: '输入字母快速查找目标节点...' })
        .fontSize(13)
        .height(36)
        .borderRadius(8)
        .backgroundColor('#FFFFFF')
        .onChange((value: string) => {
          this.targetSearchText = value
          this.targetSuggestions = this.getConnectionSuggestions(value)
        })

      if (this.targetSuggestions.length > 0) {
        Column({ space: 4 }) {
          ForEach(this.targetSuggestions, (node: WordNode) => {
            Row() {
              Text(node.word)
                .fontSize(13)
                .fontColor(COLORS.textPrimary)
                .layoutWeight(1)
            }
            .width('100%')
            .height(34)
            .padding({ left: 10, right: 10 })
            .borderRadius(6)
            .backgroundColor('#EEF2FF')
            .onClick(() => {
              this.selectTargetNode(node)
            })
          })
        }
        .width('100%')
      }

      Row({ space: 6 }) {
        Button('连接')
          .type(ButtonType.Normal)
          .fontSize(13)
          .height(36)
          .borderRadius(8)
          .backgroundColor(COLORS.primary)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .onClick(() => {
            this.connectNodes()
          })

        Button('断开')
          .type(ButtonType.Normal)
          .fontSize(13)
          .height(36)
          .borderRadius(8)
          .backgroundColor('#FEE2E2')
          .fontColor(COLORS.danger)
          .layoutWeight(1)
          .onClick(() => {
            this.disconnectNodes()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F8FAFC')
    .borderRadius(10)
  }

  private getNodeOptions(): SelectOption[] {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return []
    }
    const options: SelectOption[] = []
    for (const n of layer.nodes) {
      const opt: SelectOption = { value: n.word }
      options.push(opt)
    }
    return options
  }

  private getConnectionSuggestions(keyword: string): WordNode[] {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return []
    }

    const normalized: string = keyword.trim().toLowerCase()
    if (normalized.length === 0) {
      return []
    }

    const results: WordNode[] = []
    for (const node of layer.nodes) {
      if (node.word.toLowerCase().includes(normalized) || node.note.toLowerCase().includes(normalized)) {
        results.push(node)
        if (results.length >= 8) {
          break
        }
      }
    }

    return results
  }

  private findNodeIndexById(nodeId: number): number {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return -1
    }

    for (let i: number = 0; i < layer.nodes.length; i++) {
      if (layer.nodes[i].id === nodeId) {
        return i
      }
    }

    return -1
  }

  private selectSourceNode(node: WordNode): void {
    const index: number = this.findNodeIndexById(node.id)
    if (index >= 0) {
      this.selectedSourceIndex = index
      this.sourceSearchText = node.word
      this.sourceSuggestions = []
    }
  }

  private selectTargetNode(node: WordNode): void {
    const index: number = this.findNodeIndexById(node.id)
    if (index >= 0) {
      this.selectedTargetIndex = index
      this.targetSearchText = node.word
      this.targetSuggestions = []
    }
  }

  private getNodeLabel(index: number): string {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer || index < 0 || index >= layer.nodes.length) {
      return ''
    }
    return layer.nodes[index].word
  }

  private getSelectedNode(): WordNode | undefined {
    if (this.selectedNodeId < 0) {
      return undefined
    }

    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return undefined
    }

    for (const node of layer.nodes) {
      if (node.id === this.selectedNodeId) {
        return node
      }
    }

    return undefined
  }

  private getSelectedNodeWord(): string {
    const node: WordNode | undefined = this.getSelectedNode()
    return node ? node.word : ''
  }

  private getSelectedNodeNote(): string {
    const node: WordNode | undefined = this.getSelectedNode()
    return node ? node.note : ''
  }

  private updateSelectedNodeNote(note: string): void {
    if (this.selectedNodeId < 0) {
      return
    }

    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }

    const updatedNodes: WordNode[] = []
    let found: boolean = false

    for (const node of layer.nodes) {
      if (node.id === this.selectedNodeId) {
        updatedNodes.push({
          id: node.id,
          word: node.word,
          x: node.x,
          y: node.y,
          note: note
        })
        found = true
      } else {
        updatedNodes.push(node)
      }
    }

    if (!found) {
      return
    }

    const updatedLayer: WordLayer = {
      id: layer.id,
      name: layer.name,
      nodes: updatedNodes,
      edges: layer.edges,
      nextId: layer.nextId,
      camera: layer.camera,
      createdAt: layer.createdAt,
      updatedAt: Date.now()
    }

    this.emit({
      version: this.workspace.version,
      appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId,
      layers: this.replaceLayer(updatedLayer),
      updatedAt: Date.now()
    })
  }

  @Builder
  NodeNoteCard() {
    Column({ space: 8 }) {
      Text('节点注释')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.textSecondary)

      if (this.selectedNodeId < 0) {
        Text('请先在画布中选中一个节点，然后在这里编辑注释。')
          .fontSize(12)
          .fontColor(COLORS.textSecondary)
      } else if (!this.getSelectedNode()) {
        Text('当前选中的节点不存在，请重新选择节点。')
          .fontSize(12)
          .fontColor(COLORS.danger)
      } else {
        Text('当前节点：' + this.getSelectedNodeWord())
          .fontSize(12)
          .fontColor(COLORS.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        TextArea({
          text: this.getSelectedNodeNote(),
          placeholder: '输入节点注释；内容过长时可在输入框内上下滑动查看'
        })
          .width('100%')
          .height(180)
          .fontSize(13)
          .borderRadius(8)
          .backgroundColor('#FFFFFF')
          .padding(10)
          .onChange((value: string) => {
            this.updateSelectedNodeNote(value)
          })

        Text('长注释可在上方输入框内上下滑动查看。修改后会自动保存。')
          .fontSize(11)
          .fontColor(COLORS.textSecondary)
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F8FAFC')
    .borderRadius(10)
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
          .onClick(() => { this.onClose() })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Button(this.alphabetSorted ? '恢复顺序' : '字母排序')
              .type(ButtonType.Normal)
              .height(36)
              .fontSize(13)
              .borderRadius(8)
              .backgroundColor(this.alphabetSorted ? COLORS.primaryLight : '#F1F5F9')
              .fontColor(this.alphabetSorted ? COLORS.primary : COLORS.textPrimary)
              .layoutWeight(1)
              .onClick(() => {
                console.info(`[CP] alphabet sort clicked, alphabetSorted=${this.alphabetSorted}`)
                this.onToggleAlphabetSort()
              })
          }
          .width('100%')

          this.LayerCard()
          this.AddWordCard()
          this.SearchCard()
          this.QuickActionsCard()
          this.ConnectCard()
          this.NodeNoteCard()

          Button('清空所有数据')
            .type(ButtonType.Normal)
            .width('100%')
            .height(40)
            .fontSize(14)
            .borderRadius(8)
            .backgroundColor('#FEE2E2')
            .fontColor(COLORS.danger)
            .onClick(() => { this.clearAll() })

          Button('关闭设置面板')
            .type(ButtonType.Normal)
            .width('100%')
            .height(40)
            .fontSize(14)
            .borderRadius(8)
            .backgroundColor('#F1F5F9')
            .fontColor(COLORS.textPrimary)
            .onClick(() => { this.onClose() })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width(300)
    .height('100%')
    .padding(12)
    .backgroundColor(COLORS.panelBg)
  }
}
