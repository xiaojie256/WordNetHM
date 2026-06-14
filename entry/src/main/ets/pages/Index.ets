import { WorkspaceData, WordLayer, WordNode, WordEdge, CameraState, SaveStatus, JsonDialogMode } from '../models/GraphModels'
import { createDefaultWorkspace, normalizeWorkspace } from '../services/WorkspaceFactory'
import { WorkspaceStorage } from '../services/WorkspaceStorage'
import { showToast } from '../utils/ToastUtil'
import { AUTO_SAVE_DELAY_MS, COLORS } from '../constants/AppConstants'
import { HeaderBar } from '../components/HeaderBar'
import { GraphCanvas } from '../components/GraphCanvas'
import { ZoomControls } from '../components/ZoomControls'
import { ControlPanel } from '../components/ControlPanel'
import { ContextMenu } from '../components/ContextMenu'
import { JsonDialog } from '../components/JsonDialog'
import { RenameNodeDialog } from '../components/RenameNodeDialog'
import { RenameLayerDialog } from '../components/RenameLayerDialog'
import { CreateLayerDialog } from '../components/CreateLayerDialog'
import { common } from '@kit.AbilityKit'

@Entry
@Component
struct Index {
  @State workspace: WorkspaceData = createDefaultWorkspace()
  @State saveStatus: SaveStatus = 'saved'
  @State isPanelOpen: boolean = false
  @State isJsonDialogVisible: boolean = false
  @State jsonDialogMode: JsonDialogMode = 'export'
  @State jsonText: string = ''
  @State contextMenuVisible: boolean = false
  @State contextMenuX: number = 0
  @State contextMenuY: number = 0
  @State selectedNodeId: number = -1
  @State canvasWidth: number = 0
  @State canvasHeight: number = 0
  @State contextMenuNodeId: number = -1
  @State boxSelectMode: boolean = false
  @State selectedNodeIds: number[] = []
  @State shouldStartConnect: boolean = false
  @State alphabetSorted: boolean = false
  private nodePositionsBeforeSort: Map<number, number[]> = new Map()

  private autoSaveTimer: number = -1

  private renameNodeDialog: CustomDialogController = new CustomDialogController({
    builder: RenameNodeDialog({ currentName: '', onConfirm: () => {} }),
    autoCancel: true
  })
  private renameLayerDialog: CustomDialogController = new CustomDialogController({
    builder: RenameLayerDialog({ currentName: '', onConfirm: () => {} }),
    autoCancel: true
  })
  private createLayerDialog: CustomDialogController = new CustomDialogController({
    builder: CreateLayerDialog({ onConfirm: () => {} }),
    autoCancel: true
  })

  async aboutToAppear(): Promise<void> {
    await this.loadWorkspace()
  }

  aboutToDisappear(): void {
    if (this.autoSaveTimer >= 0) {
      clearTimeout(this.autoSaveTimer)
    }
  }

  private async loadWorkspace(): Promise<void> {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      const loaded: WorkspaceData = await WorkspaceStorage.loadWorkspace(context)
      this.workspace = loaded
    } catch (err) {
      console.error('[Index] loadWorkspace failed')
      this.workspace = createDefaultWorkspace()
    }
  }

  private async saveWorkspace(showToastFlag: boolean = false): Promise<void> {
    this.saveStatus = 'saving'
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
      await WorkspaceStorage.saveWorkspace(context, this.workspace)
      this.saveStatus = 'saved'
      if (showToastFlag) {
        showToast('保存成功')
      }
    } catch (err) {
      this.saveStatus = 'failed'
      showToast('保存失败')
    }
  }

  private scheduleAutoSave(): void {
    if (this.autoSaveTimer >= 0) {
      clearTimeout(this.autoSaveTimer)
    }
    this.autoSaveTimer = setTimeout(() => {
      this.saveWorkspace(false)
      this.autoSaveTimer = -1
    }, AUTO_SAVE_DELAY_MS) as number
  }

  private toggleBoxSelectMode(): void {
    this.boxSelectMode = !this.boxSelectMode

    if (!this.boxSelectMode) {
      this.selectedNodeIds = []
    }

    showToast(this.boxSelectMode ? '框选模式已开启' : '框选模式已关闭')
  }

  private toggleAlphabetSort(): void {
    console.info(`[Index] toggleAlphabetSort called, alphabetSorted=${this.alphabetSorted}`)
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer || layer.nodes.length === 0) {
      return
    }

    let newNodes: WordNode[] = []

    if (!this.alphabetSorted) {
      this.nodePositionsBeforeSort = new Map()
      for (const n of layer.nodes) {
        this.nodePositionsBeforeSort.set(n.id, [n.x, n.y])
      }
      const sorted: WordNode[] = [...layer.nodes].sort((a: WordNode, b: WordNode) => a.word.localeCompare(b.word))
      const cols: number = Math.max(1, Math.ceil(Math.sqrt(sorted.length)))
      const gapX: number = 160
      const gapY: number = 120
      const startX: number = 0
      const startY: number = 0
      newNodes = []
      for (let i: number = 0; i < sorted.length; i++) {
        const col: number = i % cols
        const row: number = Math.floor(i / cols)
        newNodes.push({
          id: sorted[i].id, word: sorted[i].word,
          x: startX + col * gapX, y: startY + row * gapY, note: sorted[i].note
        })
      }
      this.alphabetSorted = true
      showToast('已按字母排序')
    } else {
      newNodes = []
      for (const n of layer.nodes) {
        const pos: number[] | undefined = this.nodePositionsBeforeSort.get(n.id)
        if (pos) {
          newNodes.push({ id: n.id, word: n.word, x: pos[0], y: pos[1], note: n.note })
        } else {
          newNodes.push(n)
        }
      }
      this.nodePositionsBeforeSort = new Map()
      this.alphabetSorted = false
      showToast('已恢复原始顺序')
    }

    const updatedLayers: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id === layer.id) {
        updatedLayers.push({
          id: l.id, name: l.name, nodes: newNodes, edges: l.edges,
          nextId: l.nextId, camera: l.camera, createdAt: l.createdAt, updatedAt: Date.now()
        })
      } else {
        updatedLayers.push(l)
      }
    }

    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
    console.info(`[Index] toggleAlphabetSort done, newNodes count=${newNodes.length}`)
  }

  private openSelectedNodeMenu(): void {
    console.info(`[Index] openSelectedNodeMenu called, selectedNodeId=${this.selectedNodeId}`)
    if (this.selectedNodeId < 0) {
      showToast('请先选择一个节点')
      return
    }
    const safeX: number = this.canvasWidth > 0 ? this.canvasWidth - 180 : 220
    const safeY: number = this.canvasHeight > 0 ? 120 : 120
    this.contextMenuNodeId = this.selectedNodeId
    this.contextMenuX = safeX
    this.contextMenuY = safeY
    this.contextMenuVisible = true
  }

  private openNodeMenuAt(nodeId: number, x: number, y: number): void {
    const menuWidth: number = 160
    const menuHeight: number = 150
    const vpW: number = this.canvasWidth > 0 ? this.canvasWidth : 360
    const vpH: number = this.canvasHeight > 0 ? this.canvasHeight : 720

    let safeX: number = x
    let safeY: number = y
    if (safeX < 8) { safeX = 8 }
    if (safeY < 8) { safeY = 8 }
    if (safeX + menuWidth > vpW - 8) { safeX = vpW - menuWidth - 8 }
    if (safeY + menuHeight > vpH - 8) { safeY = vpH - menuHeight - 8 }

    this.selectedNodeId = nodeId
    this.contextMenuNodeId = nodeId
    this.contextMenuX = safeX
    this.contextMenuY = safeY
    this.contextMenuVisible = true
  }

  private moveSelectedNodes(nodeIds: number[], dx: number, dy: number): void {
    if (nodeIds.length === 0) {
      return
    }

    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }

    const updatedNodes: WordNode[] = []
    for (const node of layer.nodes) {
      if (nodeIds.includes(node.id)) {
        updatedNodes.push({
          id: node.id, word: node.word,
          x: node.x + dx, y: node.y + dy, note: node.note
        })
      } else {
        updatedNodes.push(node)
      }
    }

    const updatedLayers: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id === layer.id) {
        updatedLayers.push({
          id: l.id, name: l.name, nodes: updatedNodes, edges: l.edges,
          nextId: l.nextId, camera: l.camera, createdAt: l.createdAt, updatedAt: Date.now()
        })
      } else {
        updatedLayers.push(l)
      }
    }

    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
  }

  private onWorkspaceChange(next: WorkspaceData): void {
    this.workspace = next
    this.scheduleAutoSave()
  }

  private getCurrentCamera(): CameraState {
    for (const l of this.workspace.layers) {
      if (l.id === this.workspace.currentLayerId) {
        return l.camera
      }
    }
    const defaultCamera: CameraState = { x: 0, y: 0, scale: 1 }
    return defaultCamera
  }

  private openExportDialog(): void {
    this.jsonText = JSON.stringify(this.workspace, null, 2)
    this.jsonDialogMode = 'export'
    this.isJsonDialogVisible = true
  }

  private openImportDialog(): void {
    this.jsonText = ''
    this.jsonDialogMode = 'import'
    this.isJsonDialogVisible = true
  }

  private onImportJson(jsonText: string): void {
    try {
      const parsed: WorkspaceData = JSON.parse(jsonText) as WorkspaceData
      const normalized: WorkspaceData = normalizeWorkspace(parsed)
      this.workspace = normalized
      this.isJsonDialogVisible = false
      this.saveWorkspace(false)
      showToast('导入成功')
    } catch (err) {
      showToast('JSON 格式错误')
    }
  }

  private onLongPressNode(nodeId: number, screenX: number, screenY: number): void {
    this.openNodeMenuAt(nodeId, screenX, screenY)
  }

  private closeContextMenu(): void {
    this.contextMenuVisible = false
  }

  private renameSelectedNode(): void {
    this.contextMenuVisible = false
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    let currentNode: WordNode | undefined = undefined
    for (const n of layer.nodes) {
      if (n.id === this.selectedNodeId) {
        currentNode = n
        break
      }
    }
    if (!currentNode) {
      return
    }
    const currentName: string = currentNode.word
    const nodeId: number = currentNode.id
    this.renameNodeDialog = new CustomDialogController({
      builder: RenameNodeDialog({
        currentName: currentName,
        onConfirm: (newName: string) => {
          this.renameSelectedNodeTo(nodeId, newName)
        }
      }),
      autoCancel: true
    })
    this.renameNodeDialog.open()
  }

  private renameSelectedNodeTo(nodeId: number, newName: string): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const trimmed: string = newName.trim()
    if (trimmed.length === 0) {
      showToast('名称不能为空')
      return
    }
    for (const n of layer.nodes) {
      if (n.id !== nodeId && n.word === trimmed) {
        showToast('节点名称已存在')
        return
      }
    }
    const updatedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.id === nodeId) {
        updatedNodes.push({ id: n.id, word: trimmed, x: n.x, y: n.y, note: n.note })
      } else {
        updatedNodes.push(n)
      }
    }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: updatedNodes, edges: layer.edges,
      nextId: layer.nextId, camera: layer.camera, createdAt: layer.createdAt, updatedAt: Date.now()
    }
    this.applyLayerUpdate(updatedLayer)
    showToast('重命名成功')
  }

  private openRenameLayerDialog(): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const currentName: string = layer.name
    const layerId: string = layer.id
    this.renameLayerDialog = new CustomDialogController({
      builder: RenameLayerDialog({
        currentName: currentName,
        onConfirm: (newName: string) => {
          this.renameLayerTo(layerId, newName)
        }
      }),
      autoCancel: true
    })
    this.renameLayerDialog.open()
  }

  private renameLayerTo(layerId: string, newName: string): void {
    const trimmed: string = newName.trim()
    if (trimmed.length === 0) {
      showToast('图层名称不能为空')
      return
    }
    for (const l of this.workspace.layers) {
      if (l.id !== layerId && l.name === trimmed) {
        showToast('图层名称已存在')
        return
      }
    }
    const updatedLayers: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id === layerId) {
        updatedLayers.push({
          id: l.id, name: trimmed, nodes: l.nodes, edges: l.edges,
          nextId: l.nextId, camera: l.camera, createdAt: l.createdAt, updatedAt: Date.now()
        })
      } else {
        updatedLayers.push(l)
      }
    }
    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
    showToast('重命名成功')
  }

  private openCreateLayerDialog(): void {
    this.createLayerDialog = new CustomDialogController({
      builder: CreateLayerDialog({
        onConfirm: (name: string) => {
          this.handleCreateLayer(name)
        }
      }),
      autoCancel: true
    })
    this.createLayerDialog.open()
  }

  private handleCreateLayer(name: string): void {
    const now: number = Date.now()
    const newCamera: CameraState = { x: 0, y: 0, scale: 1 }
    const newLayer: WordLayer = {
      id: 'layer_' + now.toString(),
      name: name,
      nodes: [],
      edges: [],
      nextId: 0,
      camera: newCamera,
      createdAt: now,
      updatedAt: now
    }
    const updatedLayers: WordLayer[] = [...this.workspace.layers, newLayer]
    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: newLayer.id, layers: updatedLayers, updatedAt: now
    })
    showToast('已创建图层：' + name)
  }

  private deleteLayer(layerId: string): void {
    if (this.workspace.layers.length <= 1) {
      showToast('至少保留一个图层')
      return
    }
    const newLayers: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id !== layerId) {
        newLayers.push(l)
      }
    }
    if (newLayers.length === this.workspace.layers.length) {
      return
    }
    let newCurrentLayerId: string = this.workspace.currentLayerId
    if (this.workspace.currentLayerId === layerId) {
      newCurrentLayerId = newLayers[0].id
    }
    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: newCurrentLayerId, layers: newLayers, updatedAt: Date.now()
    })
    showToast('已删除图层')
  }

  private deleteSelectedNode(): void {
    this.contextMenuVisible = false
    if (this.selectedNodeId < 0) {
      return
    }
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const filteredNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.id !== this.selectedNodeId) {
        filteredNodes.push(n)
      }
    }
    const filteredEdges: WordEdge[] = []
    for (const e of layer.edges) {
      if (e.from !== this.selectedNodeId && e.to !== this.selectedNodeId) {
        filteredEdges.push(e)
      }
    }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: filteredNodes, edges: filteredEdges,
      nextId: layer.nextId, camera: layer.camera, createdAt: layer.createdAt, updatedAt: Date.now()
    }
    const updatedLayers: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id === updatedLayer.id) {
        updatedLayers.push(updatedLayer)
      } else {
        updatedLayers.push(l)
      }
    }
    this.selectedNodeId = -1
    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
    showToast('已删除')
  }

  private startConnectFromSelected(): void {
    this.contextMenuVisible = false
    this.shouldStartConnect = true
  }

  private getCurrentLayer(): WordLayer | undefined {
    for (const l of this.workspace.layers) {
      if (l.id === this.workspace.currentLayerId) {
        return l
      }
    }
    return undefined
  }

  build() {
    Stack() {
      Column() {
        HeaderBar({
          saveStatus: this.saveStatus,
          onImport: () => { this.openImportDialog() },
          onExport: () => { this.openExportDialog() }
        })

        Stack({ alignContent: Alignment.BottomEnd }) {
          GraphCanvas({
            workspace: this.workspace,
            selectedNodeId: this.selectedNodeId,
            boxSelectMode: this.boxSelectMode,
            selectedNodeIds: this.selectedNodeIds,
            shouldStartConnect: $shouldStartConnect,
            onWorkspaceChange: (ws: WorkspaceData) => { this.onWorkspaceChange(ws) },
            onSelectedNodeChange: (id: number) => {
              console.info(`[Index] onSelectedNodeChange: ${id}`)
              this.selectedNodeId = id
              this.contextMenuVisible = false
            },
            onLongPressNode: (id: number, sx: number, sy: number) => { this.onLongPressNode(id, sx, sy) },
            onViewportChange: (w: number, h: number) => { this.canvasWidth = w; this.canvasHeight = h },
            onMultiSelectNodes: (nodeIds: number[]) => {
              this.selectedNodeIds = nodeIds
              if (nodeIds.length > 0) {
                this.selectedNodeId = nodeIds[0]
              } else {
                this.selectedNodeId = -1
              }
              this.contextMenuVisible = false
            },
            onMoveSelectedNodes: (nodeIds: number[], dx: number, dy: number) => {
              this.moveSelectedNodes(nodeIds, dx, dy)
            }
          })
          .width('100%')
          .height('100%')

          if (this.isPanelOpen) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('#44000000')
              .position({ x: 0, y: 0 })
              .onClick(() => {
                this.isPanelOpen = false
              })

            ControlPanel({
              workspace: this.workspace,
              boxSelectMode: this.boxSelectMode,
              alphabetSorted: this.alphabetSorted,
              onWorkspaceChange: (ws: WorkspaceData) => { this.onWorkspaceChange(ws) },
              onClose: () => { this.isPanelOpen = false },
              onLocateNode: (nodeId: number) => {
                this.locateNode(nodeId)
                this.isPanelOpen = false
              },
              onRenameLayerRequest: () => {
                this.openRenameLayerDialog()
              },
              onCreateLayerRequest: () => {
                this.openCreateLayerDialog()
              },
              onDeleteLayer: (layerId: string) => {
                this.deleteLayer(layerId)
              },
              onToggleBoxSelectMode: () => {
                this.toggleBoxSelectMode()
              },
              onToggleAlphabetSort: () => {
                this.toggleAlphabetSort()
              }
            })
            .position({ x: 0, y: 0 })
            .height('100%')
            .zIndex(200)
          }

          if (!this.isPanelOpen) {
            Column() {
              Button('⚙')
                .type(ButtonType.Circle)
                .width(52)
                .height(52)
                .fontSize(22)
                .backgroundColor(COLORS.primary)
                .fontColor('#FFFFFF')
                .shadow({ radius: 8, color: '#332563EB' })
                .onClick(() => {
                  this.isPanelOpen = true
                })
            }
            .width('100%')
            .padding({ top: 12, right: 16 })
            .alignItems(HorizontalAlign.End)
            .zIndex(500)
          }

          ZoomControls({
            cameraScale: this.getCurrentCamera().scale,
            hasSelectedNode: this.selectedNodeId >= 0,
            boxSelectMode: this.boxSelectMode,
            onZoomIn: () => { this.handleZoomIn() },
            onZoomOut: () => { this.handleZoomOut() },
            onReset: () => { this.handleZoomReset() },
            onFit: () => { this.handleZoomFit() },
            onAction: () => { this.openSelectedNodeMenu() },
            onToggleBoxSelect: () => { this.toggleBoxSelectMode() }
          })

          ContextMenu({
            visible: this.contextMenuVisible,
            menuX: this.contextMenuX,
            menuY: this.contextMenuY,
            onConnect: () => { this.startConnectFromSelected() },
            onRename: () => { this.renameSelectedNode() },
            onDelete: () => { this.deleteSelectedNode() },
            onClose: () => { this.closeContextMenu() }
          })
          .zIndex(600)
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLORS.pageBg)
      .onClick(() => {
        if (this.contextMenuVisible) {
          this.contextMenuVisible = false
        }
      })

      if (this.isJsonDialogVisible) {
        Column() {
          Column() {
            JsonDialog({
              mode: this.jsonDialogMode,
              jsonText: this.jsonText,
              onImport: (jsonText: string) => { this.onImportJson(jsonText) },
              onClose: () => {
                this.isJsonDialogVisible = false
                this.jsonText = ''
              }
            })
          }
          .width('90%')
          .height('80%')
          .backgroundColor(COLORS.panelBg)
          .borderRadius(12)
          .shadow({ radius: 12, color: '#33000000' })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#44000000')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 0 })
        .zIndex(500)
        .onClick(() => {
          this.isJsonDialogVisible = false
          this.jsonText = ''
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  private locateNode(nodeId: number): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    let targetNode: WordNode | undefined = undefined
    for (const n of layer.nodes) {
      if (n.id === nodeId) {
        targetNode = n
        break
      }
    }
    if (!targetNode) {
      showToast('节点不存在')
      return
    }

    const width: number = this.canvasWidth > 0 ? this.canvasWidth : 720
    const height: number = this.canvasHeight > 0 ? this.canvasHeight : 1000

    const oldScale: number = layer.camera.scale > 0 ? layer.camera.scale : 1
    const newScale: number = oldScale < 0.8 ? 0.8 : oldScale

    const newCamera: CameraState = {
      x: width / 2 - targetNode.x * newScale,
      y: height / 2 - targetNode.y * newScale,
      scale: newScale
    }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: layer.nodes, edges: layer.edges,
      nextId: layer.nextId, camera: newCamera, createdAt: layer.createdAt, updatedAt: Date.now()
    }
    this.applyLayerUpdate(updatedLayer)
    this.selectedNodeId = nodeId
    showToast('已定位：' + targetNode.word)
  }

  private handleZoomIn(): void {
    this.applyZoom(1.2)
  }

  private handleZoomOut(): void {
    this.applyZoom(1 / 1.2)
  }

  private handleZoomReset(): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const updatedCamera: CameraState = { x: 0, y: 0, scale: 1 }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: layer.nodes, edges: layer.edges,
      nextId: layer.nextId, camera: updatedCamera, createdAt: layer.createdAt, updatedAt: Date.now()
    }
    this.applyLayerUpdate(updatedLayer)
  }

  private handleZoomFit(): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer || layer.nodes.length === 0) {
      return
    }
    let minX: number = Infinity
    let maxX: number = -Infinity
    let minY: number = Infinity
    let maxY: number = -Infinity
    for (const n of layer.nodes) {
      if (n.x < minX) { minX = n.x }
      if (n.x > maxX) { maxX = n.x }
      if (n.y < minY) { minY = n.y }
      if (n.y > maxY) { maxY = n.y }
    }
    const graphW: number = Math.max(maxX - minX, 120)
    const graphH: number = Math.max(maxY - minY, 120)
    const padding: number = 80
    const vpW: number = this.canvasWidth > 0 ? this.canvasWidth : 720
    const vpH: number = this.canvasHeight > 0 ? this.canvasHeight : 1000
    const scaleX: number = (vpW - padding * 2) / graphW
    const scaleY: number = (vpH - padding * 2) / graphH
    const nextScale: number = Math.max(0.2, Math.min(2.5, Math.min(scaleX, scaleY)))
    const centerX: number = (minX + maxX) / 2
    const centerY: number = (minY + maxY) / 2
    const updatedCamera: CameraState = {
      scale: nextScale,
      x: vpW / 2 - centerX * nextScale,
      y: vpH / 2 - centerY * nextScale
    }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: layer.nodes, edges: layer.edges,
      nextId: layer.nextId, camera: updatedCamera, createdAt: layer.createdAt, updatedAt: Date.now()
    }
    this.applyLayerUpdate(updatedLayer)
  }

  private applyZoom(factor: number): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const cam: CameraState = layer.camera
    const cx: number = this.canvasWidth > 0 ? this.canvasWidth / 2 : 360
    const cy: number = this.canvasHeight > 0 ? this.canvasHeight / 2 : 500
    const worldX: number = (cx - cam.x) / cam.scale
    const worldY: number = (cy - cam.y) / cam.scale
    const nextScale: number = Math.max(0.2, Math.min(5, cam.scale * factor))
    const updatedCamera: CameraState = {
      scale: nextScale,
      x: cx - worldX * nextScale,
      y: cy - worldY * nextScale
    }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: layer.nodes, edges: layer.edges,
      nextId: layer.nextId, camera: updatedCamera, createdAt: layer.createdAt, updatedAt: Date.now()
    }
    this.applyLayerUpdate(updatedLayer)
  }

  private applyLayerUpdate(updatedLayer: WordLayer): void {
    const updatedLayers: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id === updatedLayer.id) {
        updatedLayers.push(updatedLayer)
      } else {
        updatedLayers.push(l)
      }
    }
    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
  }
}
