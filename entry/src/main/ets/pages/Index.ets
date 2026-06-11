import { JsonDialogMode, Layer, SaveStatus, SearchResult, WordNetSettings, WordNode, Workspace } from '../models/GraphModels'
import { AUTO_SAVE_DELAY_MS, COLORS, LARGE_CONNECTION_CONFIRM_THRESHOLD } from '../constants/AppConstants'
import { createDefaultWorkspace } from '../services/WorkspaceFactory'
import { GraphService } from '../services/GraphService'
import { StorageService } from '../services/StorageService'
import { ImportExportService } from '../services/ImportExportService'
import { showToast } from '../utils/ToastUtil'
import { ensureWorkspace } from '../services/WorkspaceFactory'
import { TopBar } from '../components/TopBar'
import { GraphCanvas } from '../components/GraphCanvas'
import { LayerPanel } from '../components/LayerPanel'
import { AddNodePanel } from '../components/AddNodePanel'
import { SearchPanel } from '../components/SearchPanel'
import { QuickConnectPanel } from '../components/QuickConnectPanel'
import { NodeNotePanel } from '../components/NodeNotePanel'
import { SelectionBar } from '../components/SelectionBar'
import { SettingsPanel } from '../components/SettingsPanel'
import { JsonDialog } from '../components/JsonDialog'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

@Entry
@Component
struct Index {
  @State workspace: Workspace = createDefaultWorkspace()
  @State activeLayerId: string = ''
  @State selectedNodeIds: string[] = []
  @State connectingFromNodeId: string = ''
  @State searchKeyword: string = ''
  @State searchResultNodeIds: string[] = []
  @State highlightedNodeId: string = ''
  @State saveStatus: SaveStatus = 'saved'
  @State isSettingsVisible: boolean = false
  @State isJsonDialogVisible: boolean = false
  @State jsonDialogMode: JsonDialogMode = 'export'
  @State jsonDialogText: string = ''
  @State isSelectionMode: boolean = false
  @State screenWidth: number = 840
  @State sidePanelTab: number = 0

  private autoSaveTimer: number = -1
  private highlightTimer: number = -1
  private canvasWidth: number = 0
  private canvasHeight: number = 0

  async aboutToAppear(): Promise<void> {
    await this.initWorkspace()
  }

  aboutToDisappear(): void {
    if (this.autoSaveTimer >= 0) {
      clearTimeout(this.autoSaveTimer)
    }
    if (this.highlightTimer >= 0) {
      clearTimeout(this.highlightTimer)
    }
  }

  private async initWorkspace(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const saved: Workspace | undefined = await StorageService.loadWorkspace(context)
      if (saved) {
        const ensured: Workspace = ensureWorkspace(saved)
        this.workspace = ensured
        this.activeLayerId = ensured.activeLayerId
      } else {
        const defaultWs: Workspace = createDefaultWorkspace()
        this.workspace = defaultWs
        this.activeLayerId = defaultWs.activeLayerId
      }
    } catch (err) {
      console.error(`[Index] initWorkspace failed: ${err}`)
      const defaultWs: Workspace = createDefaultWorkspace()
      this.workspace = defaultWs
      this.activeLayerId = defaultWs.activeLayerId
    }
  }

  private async saveWorkspace(showToastFlag: boolean = false): Promise<void> {
    this.saveStatus = 'saving'
    try {
      const context = getContext(this) as common.UIAbilityContext
      await StorageService.saveWorkspace(context, this.workspace)
      this.saveStatus = 'saved'
      if (showToastFlag) {
        showToast('保存成功')
      }
    } catch (err) {
      this.saveStatus = 'failed'
      showToast('保存失败，请导出 JSON 备份')
    }
  }

  private scheduleAutoSave(): void {
    if (!this.workspace.settings.autoSave) {
      return
    }
    if (this.autoSaveTimer >= 0) {
      clearTimeout(this.autoSaveTimer)
    }
    this.autoSaveTimer = setTimeout(() => {
      this.saveWorkspace(false)
      this.autoSaveTimer = -1
    }, AUTO_SAVE_DELAY_MS) as unknown as number
  }

  private setWorkspace(next: Workspace): void {
    this.workspace = next
    this.activeLayerId = next.activeLayerId
    this.scheduleAutoSave()
  }

  private getActiveLayer(): Layer | undefined {
    return GraphService.getActiveLayer(this.workspace)
  }

  private onAddNode(label: string): void {
    const layer: Layer | undefined = this.getActiveLayer()
    if (!layer) {
      return
    }

    const centerX: number = (this.canvasWidth / 2 - layer.viewport.x) / layer.viewport.zoom
    const centerY: number = (this.canvasHeight / 2 - layer.viewport.y) / layer.viewport.zoom
    const offset: number = (layer.nodes.length % 5) * 28

    const before: number = layer.nodes.length
    const next: Workspace = GraphService.addNode(this.workspace, label, centerX + offset, centerY + offset)
    if (next === this.workspace) {
      showToast('该单词已存在')
      return
    }

    const updatedLayer: Layer | undefined = GraphService.getActiveLayer(next)
    if (updatedLayer && updatedLayer.nodes.length > before) {
      const newNode: WordNode = updatedLayer.nodes[updatedLayer.nodes.length - 1]
      this.selectedNodeIds = [newNode.id]
    }

    this.setWorkspace(next)
  }

  private onRenameNode(nodeId: string, newLabel: string): void {
    const next: Workspace = GraphService.renameNode(this.workspace, nodeId, newLabel)
    if (next === this.workspace) {
      showToast('节点名称不能为空或已存在')
      return
    }
    this.setWorkspace(next)
  }

  private onDeleteSelected(): void {
    if (this.selectedNodeIds.length === 0) {
      return
    }

    if (this.workspace.settings.confirmBeforeDelete) {
      const count: number = this.selectedNodeIds.length
      promptAction.showDialog({
        title: '确认删除',
        message: `确定删除选中的 ${count} 个节点吗？这些节点相关的连接也会被删除。`,
        buttons: [
          { text: '取消', color: COLORS.textSecondary },
          { text: '删除', color: COLORS.danger }
        ]
      }).then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) {
          this.doDeleteSelected()
        }
      })
    } else {
      this.doDeleteSelected()
    }
  }

  private doDeleteSelected(): void {
    const next: Workspace = GraphService.deleteNodes(this.workspace, this.selectedNodeIds)
    this.selectedNodeIds = []
    this.setWorkspace(next)
    showToast('删除成功')
  }

  private onNodePositionChange(nodeId: string, x: number, y: number): void {
    const next: Workspace = GraphService.updateNodePosition(this.workspace, nodeId, x, y)
    this.setWorkspace(next)
  }

  private onMoveSelectedNodes(deltaX: number, deltaY: number): void {
    const next: Workspace = GraphService.moveNodes(this.workspace, this.selectedNodeIds, deltaX, deltaY)
    this.setWorkspace(next)
  }

  private onSelectSingle(nodeId: string): void {
    this.selectedNodeIds = [nodeId]
    this.isSelectionMode = false
  }

  private onSelectMultiple(nodeIds: string[]): void {
    this.selectedNodeIds = nodeIds
    this.isSelectionMode = nodeIds.length > 1
  }

  private onClearSelection(): void {
    this.selectedNodeIds = []
    this.isSelectionMode = false
    this.connectingFromNodeId = ''
  }

  private onStartConnect(nodeId: string): void {
    this.connectingFromNodeId = nodeId
    showToast('点击目标节点完成连接')
  }

  private onCompleteConnect(targetNodeId: string): void {
    if (this.connectingFromNodeId.length === 0) {
      return
    }
    const next: Workspace = GraphService.connectNodes(this.workspace, this.connectingFromNodeId, targetNodeId)
    if (next === this.workspace) {
      showToast('连接已存在')
    } else {
      showToast('连接成功')
    }
    this.connectingFromNodeId = ''
    this.setWorkspace(next)
  }

  private onConnectNodes(sourceId: string, targetId: string): void {
    const next: Workspace = GraphService.connectNodes(this.workspace, sourceId, targetId)
    if (next === this.workspace) {
      showToast('连接已存在或无效')
    } else {
      showToast('连接成功')
      this.setWorkspace(next)
    }
  }

  private onDisconnectNodes(sourceId: string, targetId: string): void {
    const next: Workspace = GraphService.disconnectNodes(this.workspace, sourceId, targetId)
    if (next === this.workspace) {
      showToast('连接不存在')
    } else {
      showToast('断开成功')
      this.setWorkspace(next)
    }
  }

  private onConnectSelectedAll(): void {
    if (this.selectedNodeIds.length < 2) {
      showToast('至少选择两个节点')
      return
    }

    const count: number = this.selectedNodeIds.length
    const newConnectionCount: number = count * (count - 1) / 2

    if (newConnectionCount > LARGE_CONNECTION_CONFIRM_THRESHOLD) {
      promptAction.showDialog({
        title: '确认连接',
        message: `即将创建 ${newConnectionCount} 条连接，是否继续？`,
        buttons: [
          { text: '取消', color: COLORS.textSecondary },
          { text: '确认', color: COLORS.primary }
        ]
      }).then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) {
          this.doConnectSelectedAll()
        }
      })
    } else {
      this.doConnectSelectedAll()
    }
  }

  private doConnectSelectedAll(): void {
    const next: Workspace = GraphService.connectAllSelected(this.workspace, this.selectedNodeIds)
    if (next === this.workspace) {
      showToast('所有连接已存在')
    } else {
      showToast('连接成功')
      this.setWorkspace(next)
    }
  }

  private onDisconnectSelected(): void {
    if (this.selectedNodeIds.length < 2) {
      showToast('至少选择两个节点')
      return
    }
    const next: Workspace = GraphService.disconnectSelected(this.workspace, this.selectedNodeIds)
    if (next === this.workspace) {
      showToast('无连接可断开')
    } else {
      showToast('断开成功')
      this.setWorkspace(next)
    }
  }

  private onUpdateNodeNote(nodeId: string, note: string): void {
    const next: Workspace = GraphService.updateNodeNote(this.workspace, nodeId, note)
    this.setWorkspace(next)
  }

  private onSearch(keyword: string): SearchResult[] {
    return GraphService.searchCurrentLayer(this.workspace, keyword)
  }

  private onLocateNode(nodeId: string): void {
    const layer: Layer | undefined = this.getActiveLayer()
    if (!layer) {
      return
    }

    const node: WordNode | undefined = layer.nodes.find((n: WordNode) => n.id === nodeId)
    if (!node) {
      return
    }

    const newX: number = this.canvasWidth / 2 - node.x * layer.viewport.zoom
    const newY: number = this.canvasHeight / 2 - node.y * layer.viewport.zoom
    const next: Workspace = GraphService.updateActiveViewport(this.workspace, newX, newY, layer.viewport.zoom)
    this.setWorkspace(next)

    this.highlightedNodeId = nodeId
    if (this.highlightTimer >= 0) {
      clearTimeout(this.highlightTimer)
    }
    this.highlightTimer = setTimeout(() => {
      this.highlightedNodeId = ''
      this.highlightTimer = -1
    }, 1500) as unknown as number

    this.selectedNodeIds = [nodeId]
  }

  private onCreateLayer(): void {
    const next: Workspace = GraphService.createLayer(this.workspace)
    this.selectedNodeIds = []
    this.setWorkspace(next)
  }

  private onCopyLayer(): void {
    const next: Workspace = GraphService.copyActiveLayer(this.workspace)
    this.selectedNodeIds = []
    this.setWorkspace(next)
  }

  private onRenameLayer(newName: string): void {
    const next: Workspace = GraphService.renameActiveLayer(this.workspace, newName)
    this.setWorkspace(next)
  }

  private onSwitchLayer(layerId: string): void {
    const next: Workspace = GraphService.switchLayer(this.workspace, layerId)
    this.selectedNodeIds = []
    this.connectingFromNodeId = ''
    this.setWorkspace(next)
  }

  private onClearAllData(): void {
    const defaultWs: Workspace = createDefaultWorkspace()
    this.workspace = defaultWs
    this.activeLayerId = defaultWs.activeLayerId
    this.selectedNodeIds = []
    this.connectingFromNodeId = ''
    this.isSettingsVisible = false
    this.saveWorkspace(false)
    showToast('清空成功')
  }

  private onOpenImportDialog(): void {
    this.jsonDialogMode = 'import'
    this.jsonDialogText = ''
    this.isJsonDialogVisible = true
  }

  private onImportJson(jsonText: string): void {
    try {
      const imported: Workspace = ImportExportService.importFromJson(jsonText)
      this.workspace = imported
      this.activeLayerId = imported.activeLayerId
      this.selectedNodeIds = []
      this.connectingFromNodeId = ''
      this.isJsonDialogVisible = false
      this.saveWorkspace(false)
      showToast('导入成功')
    } catch (err) {
      showToast(`导入失败: ${err}`)
    }
  }

  private onOpenExportDialog(): void {
    this.jsonDialogMode = 'export'
    this.jsonDialogText = ImportExportService.exportToJson(this.workspace)
    this.isJsonDialogVisible = true
  }

  private onUpdateSettings(settings: WordNetSettings): void {
    const next: Workspace = { ...this.workspace, settings: settings }
    this.setWorkspace(next)
  }

  private onDeleteSingleNode(nodeId: string): void {
    this.selectedNodeIds = [nodeId]
    this.onDeleteSelected()
  }

  private getSelectedNodeLabel(): string {
    if (this.selectedNodeIds.length === 1) {
      const layer: Layer | undefined = this.getActiveLayer()
      if (layer) {
        const node: WordNode | undefined = layer.nodes.find(
          (n: WordNode) => n.id === this.selectedNodeIds[0]
        )
        if (node) {
          return node.label
        }
      }
    }
    return ''
  }

  private getSelectedNodeNote(): string {
    if (this.selectedNodeIds.length === 1) {
      const layer: Layer | undefined = this.getActiveLayer()
      if (layer) {
        const node: WordNode | undefined = layer.nodes.find(
          (n: WordNode) => n.id === this.selectedNodeIds[0]
        )
        if (node) {
          return node.note
        }
      }
    }
    return ''
  }

  private isLargeScreen(): boolean {
    return this.screenWidth >= 840
  }

  build() {
    Column() {
      TopBar({
        saveStatus: this.saveStatus,
        onImport: () => { this.onOpenImportDialog() },
        onSave: () => { this.saveWorkspace(true) },
        onExport: () => { this.onOpenExportDialog() },
        onOpenSettings: () => { this.isSettingsVisible = true }
      })

      if (this.isLargeScreen()) {
        Row() {
          GraphCanvas({
            workspace: this.workspace,
            activeLayerId: this.activeLayerId,
            selectedNodeIds: this.selectedNodeIds,
            highlightedNodeId: this.highlightedNodeId,
            connectingFromNodeId: this.connectingFromNodeId,
            showGrid: this.workspace.settings.showGrid,
            onSelectSingle: (nodeId: string) => { this.onSelectSingle(nodeId) },
            onSelectMultiple: (nodeIds: string[]) => { this.onSelectMultiple(nodeIds) },
            onClearSelection: () => { this.onClearSelection() },
            onNodePositionChange: (nodeId: string, x: number, y: number) => { this.onNodePositionChange(nodeId, x, y) },
            onMoveSelectedNodes: (dx: number, dy: number) => { this.onMoveSelectedNodes(dx, dy) },
            onViewportChange: (x: number, y: number, zoom: number) => {
              const next = GraphService.updateActiveViewport(this.workspace, x, y, zoom)
              this.setWorkspace(next)
            },
            onCompleteConnect: (nodeId: string) => { this.onCompleteConnect(nodeId) },
            onCanvasReady: (w: number, h: number) => {
              this.canvasWidth = w
              this.canvasHeight = h
            }
          })
          .layoutWeight(1)

          Column() {
            Tabs({ barPosition: BarPosition.Start }) {
              TabContent() {
                LayerPanel({
                  layerNames: this.workspace.layers.map((l: Layer) => l.name),
                  layerIds: this.workspace.layers.map((l: Layer) => l.id),
                  activeLayerId: this.activeLayerId,
                  onCreateLayer: () => { this.onCreateLayer() },
                  onCopyLayer: () => { this.onCopyLayer() },
                  onRenameLayer: (name: string) => { this.onRenameLayer(name) },
                  onSwitchLayer: (layerId: string) => { this.onSwitchLayer(layerId) }
                })
              }
              .tabBar({ builder: () => { Text('图层').fontSize(13).padding(8) } })

              TabContent() {
                AddNodePanel({
                  onAddNode: (label: string) => { this.onAddNode(label) }
                })
              }
              .tabBar({ builder: () => { Text('添加').fontSize(13).padding(8) } })

              TabContent() {
                Column() {
                  SearchPanel({
                    onSearch: (keyword: string) => { return this.onSearch(keyword) },
                    onLocateNode: (nodeId: string) => { this.onLocateNode(nodeId) }
                  })

                  Divider().margin({ top: 4, bottom: 4 })

                  QuickConnectPanel({
                    nodeLabels: this.getActiveLayer()?.nodes.map((n: WordNode) => n.label) ?? [],
                    nodeIds: this.getActiveLayer()?.nodes.map((n: WordNode) => n.id) ?? [],
                    onConnect: (sourceId: string, targetId: string) => { this.onConnectNodes(sourceId, targetId) },
                    onDisconnect: (sourceId: string, targetId: string) => { this.onDisconnectNodes(sourceId, targetId) }
                  })
                }
              }
              .tabBar({ builder: () => { Text('搜索').fontSize(13).padding(8) } })

              TabContent() {
                NodeNotePanel({
                  selectedNodeIds: this.selectedNodeIds,
                  selectedNodeLabel: this.getSelectedNodeLabel(),
                  nodeId: this.selectedNodeIds.length === 1 ? this.selectedNodeIds[0] : '',
                  onUpdateNote: (nodeId: string, note: string) => { this.onUpdateNodeNote(nodeId, note) },
                  onRenameNode: (nodeId: string, label: string) => { this.onRenameNode(nodeId, label) },
                  onStartConnect: (nodeId: string) => { this.onStartConnect(nodeId) },
                  onDeleteNode: (nodeId: string) => { this.onDeleteSingleNode(nodeId) }
                })
              }
              .tabBar({ builder: () => { Text('注释').fontSize(13).padding(8) } })
            }
            .barWidth(340)
            .barHeight(40)
            .scrollable(true)
            .animationDuration(0)
          }
          .width(340)
          .height('100%')
          .backgroundColor(COLORS.panelBg)
          .border({ width: { left: 1 }, color: COLORS.panelBorder })
        }
        .layoutWeight(1)
      } else {
        Column() {
          GraphCanvas({
            workspace: this.workspace,
            activeLayerId: this.activeLayerId,
            selectedNodeIds: this.selectedNodeIds,
            highlightedNodeId: this.highlightedNodeId,
            connectingFromNodeId: this.connectingFromNodeId,
            showGrid: this.workspace.settings.showGrid,
            onSelectSingle: (nodeId: string) => { this.onSelectSingle(nodeId) },
            onSelectMultiple: (nodeIds: string[]) => { this.onSelectMultiple(nodeIds) },
            onClearSelection: () => { this.onClearSelection() },
            onNodePositionChange: (nodeId: string, x: number, y: number) => { this.onNodePositionChange(nodeId, x, y) },
            onMoveSelectedNodes: (dx: number, dy: number) => { this.onMoveSelectedNodes(dx, dy) },
            onViewportChange: (x: number, y: number, zoom: number) => {
              const next = GraphService.updateActiveViewport(this.workspace, x, y, zoom)
              this.setWorkspace(next)
            },
            onCompleteConnect: (nodeId: string) => { this.onCompleteConnect(nodeId) },
            onCanvasReady: (w: number, h: number) => {
              this.canvasWidth = w
              this.canvasHeight = h
            }
          })
          .layoutWeight(1)

          Column() {
            Tabs({ barPosition: BarPosition.Start }) {
              TabContent() {
                LayerPanel({
                  layerNames: this.workspace.layers.map((l: Layer) => l.name),
                  layerIds: this.workspace.layers.map((l: Layer) => l.id),
                  activeLayerId: this.activeLayerId,
                  onCreateLayer: () => { this.onCreateLayer() },
                  onCopyLayer: () => { this.onCopyLayer() },
                  onRenameLayer: (name: string) => { this.onRenameLayer(name) },
                  onSwitchLayer: (layerId: string) => { this.onSwitchLayer(layerId) }
                })
              }
              .tabBar({ builder: () => { Text('图层').fontSize(12).padding(6) } })

              TabContent() {
                AddNodePanel({
                  onAddNode: (label: string) => { this.onAddNode(label) }
                })
              }
              .tabBar({ builder: () => { Text('添加').fontSize(12).padding(6) } })

              TabContent() {
                Column() {
                  SearchPanel({
                    onSearch: (keyword: string) => { return this.onSearch(keyword) },
                    onLocateNode: (nodeId: string) => { this.onLocateNode(nodeId) }
                  })

                  Divider().margin({ top: 4, bottom: 4 })

                  QuickConnectPanel({
                    nodeLabels: this.getActiveLayer()?.nodes.map((n: WordNode) => n.label) ?? [],
                    nodeIds: this.getActiveLayer()?.nodes.map((n: WordNode) => n.id) ?? [],
                    onConnect: (sourceId: string, targetId: string) => { this.onConnectNodes(sourceId, targetId) },
                    onDisconnect: (sourceId: string, targetId: string) => { this.onDisconnectNodes(sourceId, targetId) }
                  })
                }
              }
              .tabBar({ builder: () => { Text('搜索').fontSize(12).padding(6) } })

              TabContent() {
                NodeNotePanel({
                  selectedNodeIds: this.selectedNodeIds,
                  selectedNodeLabel: this.getSelectedNodeLabel(),
                  nodeId: this.selectedNodeIds.length === 1 ? this.selectedNodeIds[0] : '',
                  onUpdateNote: (nodeId: string, note: string) => { this.onUpdateNodeNote(nodeId, note) },
                  onRenameNode: (nodeId: string, label: string) => { this.onRenameNode(nodeId, label) },
                  onStartConnect: (nodeId: string) => { this.onStartConnect(nodeId) },
                  onDeleteNode: (nodeId: string) => { this.onDeleteSingleNode(nodeId) }
                })
              }
              .tabBar({ builder: () => { Text('注释').fontSize(12).padding(6) } })
            }
            .barHeight(36)
            .scrollable(true)
            .animationDuration(0)
          }
          .width('100%')
          .height(240)
          .backgroundColor(COLORS.panelBg)
          .border({ width: { top: 1 }, color: COLORS.panelBorder })
        }
        .width('100%')
        .height('100%')
      }

      if (this.selectedNodeIds.length > 1) {
        SelectionBar({
          selectedCount: this.selectedNodeIds.length,
          onConnectAll: () => { this.onConnectSelectedAll() },
          onDisconnectSelected: () => { this.onDisconnectSelected() },
          onDeleteSelected: () => { this.onDeleteSelected() },
          onCancel: () => { this.onClearSelection() }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.pageBg)
    .onAreaChange((_oldVal: Area, newVal: Area) => {
      this.screenWidth = newVal.width as number
    })

    if (this.isSettingsVisible) {
      Column() {
        Column() {
          SettingsPanel({
            settings: this.workspace.settings,
            onUpdateSettings: (settings: WordNetSettings) => { this.onUpdateSettings(settings) },
            onClearAllData: () => { this.onClearAllData() },
            onClose: () => { this.isSettingsVisible = false }
          })
        }
        .width(this.isLargeScreen() ? 380 : '90%')
        .maxHeight('80%')
        .backgroundColor(COLORS.panelBg)
        .borderRadius(12)
        .shadow({ radius: 12, color: '#33000000' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#33000000')
      .justifyContent(FlexAlign.Center)
      .position({ x: 0, y: 0 })
      .onClick(() => {
        this.isSettingsVisible = false
      })
    }

    if (this.isJsonDialogVisible) {
      Column() {
        Column() {
          JsonDialog({
            mode: this.jsonDialogMode,
            jsonText: this.jsonDialogText,
            onImport: (jsonText: string) => { this.onImportJson(jsonText) },
            onClose: () => { this.isJsonDialogVisible = false }
          })
        }
        .width(this.isLargeScreen() ? 480 : '95%')
        .maxHeight('85%')
        .backgroundColor(COLORS.panelBg)
        .borderRadius(12)
        .shadow({ radius: 12, color: '#33000000' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#33000000')
      .justifyContent(FlexAlign.Center)
      .position({ x: 0, y: 0 })
      .onClick(() => {
        this.isJsonDialogVisible = false
      })
    }
  }
}
