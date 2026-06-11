import { CameraState, WordLayer, WordNode, WordEdge, WorkspaceData } from '../models/GraphModels'
import { createDefaultWorkspace } from '../services/WorkspaceFactory'
import { COLORS, NODE_RADIUS, MIN_SCALE, MAX_SCALE, ZOOM_FACTOR, LONG_PRESS_MS, LONG_PRESS_MOVE_THRESHOLD } from '../constants/AppConstants'
import { showToast } from '../utils/ToastUtil'

interface Point2D {
  x: number
  y: number
}

@Component
export struct GraphCanvas {
  @Prop @Watch('onDataChange') workspace: WorkspaceData = createDefaultWorkspace()
  @Prop selectedNodeId: number = -1
  @State connectingFromId: number = -1
  @State highlightNodeId: number = -1
  onWorkspaceChange: (ws: WorkspaceData) => void = (ws: WorkspaceData) => {}
  onSelectedNodeChange: (nodeId: number) => void = (id: number) => {}
  onLongPressNode: (nodeId: number, screenX: number, screenY: number) => void =
    (id: number, sx: number, sy: number) => {}
  onViewportChange: (width: number, height: number) => void = (w: number, h: number) => {}
  boxSelectMode: boolean = false
  selectedNodeIds: number[] = []
  onMultiSelectNodes: (nodeIds: number[]) => void = (nodeIds: number[]) => {}
  onMoveSelectedNodes: (nodeIds: number[], dx: number, dy: number) => void =
    (nodeIds: number[], dx: number, dy: number) => {}
  @Link @Watch('onStartConnectChange') shouldStartConnect: boolean

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private canvasWidth: number = 0
  private canvasHeight: number = 0
  private isCanvasReady: boolean = false
  private camera: CameraState = { x: 0, y: 0, scale: 1 }

  private isDraggingNode: boolean = false
  private isPanning: boolean = false
  private isPinching: boolean = false
  private draggingNodeId: number = -1
  private dragStartX: number = 0
  private dragStartY: number = 0
  private lastX: number = 0
  private lastY: number = 0
  private longPressTimer: number = -1
  private longPressTriggered: boolean = false
  private longPressNodeId: number = -1
  private longPressStartX: number = 0
  private longPressStartY: number = 0
  private longPressMenuX: number = 0
  private longPressMenuY: number = 0
  private pinchStartDistance: number = 0
  private pinchStartScale: number = 1
  private pinchCenterX: number = 0
  private pinchCenterY: number = 0

  @State isBoxSelecting: boolean = false
  @State boxStartX: number = 0
  @State boxStartY: number = 0
  @State boxCurrentX: number = 0
  @State boxCurrentY: number = 0
  private isDraggingMultiNodes: boolean = false
  private multiDragLastWorldX: number = 0
  private multiDragLastWorldY: number = 0

  private safeRedraw(): void {
    if (this.isCanvasReady) {
      this.redraw()
    }
  }

  private onDataChange(): void {
    this.syncCameraFromLayer()
    this.safeRedraw()
  }

  private syncCameraFromLayer(): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (layer) {
      this.camera = { x: layer.camera.x, y: layer.camera.y, scale: layer.camera.scale }
    }
  }

  aboutToAppear(): void {
    this.syncCameraFromLayer()
  }

  private getCurrentLayer(): WordLayer | undefined {
    for (const l of this.workspace.layers) {
      if (l.id === this.workspace.currentLayerId) {
        return l
      }
    }
    return undefined
  }

  private toWorld(screenX: number, screenY: number): Point2D {
    return {
      x: (screenX - this.camera.x) / this.camera.scale,
      y: (screenY - this.camera.y) / this.camera.scale
    }
  }

  private toScreen(worldX: number, worldY: number): Point2D {
    return {
      x: worldX * this.camera.scale + this.camera.x,
      y: worldY * this.camera.scale + this.camera.y
    }
  }

  private clampScale(s: number): number {
    return Math.max(MIN_SCALE, Math.min(MAX_SCALE, s))
  }

  private emitCameraChange(): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: layer.nodes, edges: layer.edges,
      nextId: layer.nextId, camera: { x: this.camera.x, y: this.camera.y, scale: this.camera.scale },
      createdAt: layer.createdAt, updatedAt: Date.now()
    }
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

  private emitNodePositionChange(nodeId: number, x: number, y: number): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return
    }
    const updatedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.id === nodeId) {
        updatedNodes.push({ id: n.id, word: n.word, x: x, y: y, note: n.note })
      } else {
        updatedNodes.push(n)
      }
    }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: updatedNodes, edges: layer.edges,
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
    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
  }

  public zoomIn(): void {
    this.zoomAtCenter(ZOOM_FACTOR)
  }

  public zoomOut(): void {
    this.zoomAtCenter(1 / ZOOM_FACTOR)
  }

  public resetZoom(): void {
    this.camera = { x: 0, y: 0, scale: 1 }
    this.emitCameraChange()
    this.safeRedraw()
  }

  public fitView(): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer || layer.nodes.length === 0) {
      this.camera = { x: this.canvasWidth / 2, y: this.canvasHeight / 2, scale: 1 }
      this.emitCameraChange()
      this.safeRedraw()
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
    const scaleX: number = (this.canvasWidth - padding * 2) / graphW
    const scaleY: number = (this.canvasHeight - padding * 2) / graphH
    const nextScale: number = this.clampScale(Math.min(scaleX, scaleY))
    const centerX: number = (minX + maxX) / 2
    const centerY: number = (minY + maxY) / 2
    this.camera = {
      scale: nextScale,
      x: this.canvasWidth / 2 - centerX * nextScale,
      y: this.canvasHeight / 2 - centerY * nextScale
    }
    this.emitCameraChange()
    this.safeRedraw()
  }

  private zoomAtCenter(factor: number): void {
    const cx: number = this.canvasWidth / 2
    const cy: number = this.canvasHeight / 2
    this.zoomAt(cx, cy, factor)
  }

  private zoomAt(screenX: number, screenY: number, factor: number): void {
    const before: Point2D = this.toWorld(screenX, screenY)
    const nextScale: number = this.clampScale(this.camera.scale * factor)
    this.camera.scale = nextScale
    this.camera.x = screenX - before.x * nextScale
    this.camera.y = screenY - before.y * nextScale
    this.emitCameraChange()
    this.safeRedraw()
  }

  public selectNode(nodeId: number): void {
    this.onSelectedNodeChange(nodeId)
    this.safeRedraw()
  }

  public highlightNode(nodeId: number): void {
    this.highlightNodeId = nodeId
    this.safeRedraw()
  }

  private hitTestNode(screenX: number, screenY: number): WordNode | undefined {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return undefined
    }
    const world: Point2D = this.toWorld(screenX, screenY)
    for (let i: number = layer.nodes.length - 1; i >= 0; i--) {
      const node: WordNode = layer.nodes[i]
      const dx: number = node.x - world.x
      const dy: number = node.y - world.y
      if (Math.sqrt(dx * dx + dy * dy) <= NODE_RADIUS) {
        return node
      }
    }
    return undefined
  }

  private clearLongPressTimer(): void {
    if (this.longPressTimer >= 0) {
      clearTimeout(this.longPressTimer)
      this.longPressTimer = -1
    }
  }

  private startLongPressIfNode(screenX: number, screenY: number): void {
    this.clearLongPressTimer()
    this.longPressNodeId = -1

    const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY)
    if (!hitNode) {
      return
    }

    this.longPressNodeId = hitNode.id
    this.longPressStartX = screenX
    this.longPressStartY = screenY
    this.longPressMenuX = Math.max(10, Math.min(screenX, this.canvasWidth - 140))
    this.longPressMenuY = Math.max(10, Math.min(screenY, this.canvasHeight - 130))

    this.longPressTimer = setTimeout(() => {
      if (this.longPressNodeId >= 0) {
        this.longPressTriggered = true
        this.isDraggingNode = false
        this.onLongPressNode(this.longPressNodeId, this.longPressMenuX, this.longPressMenuY)
      }
      this.longPressTimer = -1
    }, LONG_PRESS_MS) as number
  }

  private handleBoxSelectDown(screenX: number, screenY: number): boolean {
    if (!this.boxSelectMode) {
      return false
    }

    const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY)

    if (hitNode) {
      if (this.selectedNodeIds.includes(hitNode.id)) {
        const worldPoint: Point2D = this.toWorld(screenX, screenY)
        this.isDraggingMultiNodes = true
        this.multiDragLastWorldX = worldPoint.x
        this.multiDragLastWorldY = worldPoint.y
        return true
      }

      this.onMultiSelectNodes([hitNode.id])
      return true
    }

    this.isBoxSelecting = true
    this.boxStartX = screenX
    this.boxStartY = screenY
    this.boxCurrentX = screenX
    this.boxCurrentY = screenY
    this.onMultiSelectNodes([])

    return true
  }

  private handleBoxSelectMove(screenX: number, screenY: number): boolean {
    if (!this.boxSelectMode) {
      return false
    }

    if (this.isBoxSelecting) {
      this.boxCurrentX = screenX
      this.boxCurrentY = screenY
      this.safeRedraw()
      return true
    }

    if (this.isDraggingMultiNodes) {
      const worldPoint: Point2D = this.toWorld(screenX, screenY)

      const dx: number = worldPoint.x - this.multiDragLastWorldX
      const dy: number = worldPoint.y - this.multiDragLastWorldY

      this.multiDragLastWorldX = worldPoint.x
      this.multiDragLastWorldY = worldPoint.y

      if (this.selectedNodeIds.length > 0) {
        this.onMoveSelectedNodes(this.selectedNodeIds, dx, dy)
      }

      return true
    }

    return false
  }

  private handleBoxSelectUp(): boolean {
    if (!this.boxSelectMode) {
      return false
    }

    if (this.isDraggingMultiNodes) {
      this.isDraggingMultiNodes = false
      return true
    }

    if (!this.isBoxSelecting) {
      return false
    }

    const selectedIds: number[] = this.getNodesInSelectionBox()

    this.isBoxSelecting = false
    this.safeRedraw()

    this.onMultiSelectNodes(selectedIds)

    if (selectedIds.length > 0) {
      showToast('已选中 ' + selectedIds.length.toString() + ' 个节点')
    } else {
      showToast('未选中节点')
    }

    return true
  }

  private getNodesInSelectionBox(): number[] {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) {
      return []
    }

    const left: number = Math.min(this.boxStartX, this.boxCurrentX)
    const right: number = Math.max(this.boxStartX, this.boxCurrentX)
    const top: number = Math.min(this.boxStartY, this.boxCurrentY)
    const bottom: number = Math.max(this.boxStartY, this.boxCurrentY)

    const topLeftWorld: Point2D = this.toWorld(left, top)
    const bottomRightWorld: Point2D = this.toWorld(right, bottom)

    const worldLeft: number = Math.min(topLeftWorld.x, bottomRightWorld.x)
    const worldRight: number = Math.max(topLeftWorld.x, bottomRightWorld.x)
    const worldTop: number = Math.min(topLeftWorld.y, bottomRightWorld.y)
    const worldBottom: number = Math.max(topLeftWorld.y, bottomRightWorld.y)

    const ids: number[] = []

    for (const node of layer.nodes) {
      if (
        node.x >= worldLeft &&
        node.x <= worldRight &&
        node.y >= worldTop &&
        node.y <= worldBottom
      ) {
        ids.push(node.id)
      }
    }

    return ids
  }

  private drawSelectionBox(ctx: CanvasRenderingContext2D): void {
    if (!this.isBoxSelecting) {
      return
    }

    const left: number = Math.min(this.boxStartX, this.boxCurrentX)
    const top: number = Math.min(this.boxStartY, this.boxCurrentY)
    const width: number = Math.abs(this.boxCurrentX - this.boxStartX)
    const height: number = Math.abs(this.boxCurrentY - this.boxStartY)

    if (width < 2 && height < 2) {
      return
    }

    ctx.save()
    ctx.strokeStyle = COLORS.primary
    ctx.lineWidth = 1.5
    ctx.setLineDash([6, 4])
    ctx.strokeRect(left, top, width, height)
    ctx.restore()
  }

  private handlePointerDown(screenX: number, screenY: number): void {
    if (this.longPressTriggered) {
      this.longPressTriggered = false
      return
    }

    if (this.handleBoxSelectDown(screenX, screenY)) {
      return
    }

    this.lastX = screenX
    this.lastY = screenY

    const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY)

    if (hitNode) {
      if (this.connectingFromId >= 0 && hitNode.id !== this.connectingFromId) {
        this.completeConnection(hitNode.id)
        return
      }
      this.isDraggingNode = true
      this.draggingNodeId = hitNode.id
      this.dragStartX = screenX
      this.dragStartY = screenY
      this.onSelectedNodeChange(hitNode.id)
    } else {
      this.isPanning = true
      this.onSelectedNodeChange(-1)
      this.connectingFromId = -1
    }
    this.safeRedraw()
  }

  private handlePointerMove(screenX: number, screenY: number): void {
    if (this.handleBoxSelectMove(screenX, screenY)) {
      return
    }

    if (this.isDraggingNode && !this.longPressTriggered) {
      if (this.longPressNodeId >= 0) {
        const dxFromStart: number = screenX - this.longPressStartX
        const dyFromStart: number = screenY - this.longPressStartY
        const distFromStart: number = Math.sqrt(dxFromStart * dxFromStart + dyFromStart * dyFromStart)
        if (distFromStart > LONG_PRESS_MOVE_THRESHOLD) {
          this.clearLongPressTimer()
          this.longPressNodeId = -1
        } else {
          this.lastX = screenX
          this.lastY = screenY
          return
        }
      }

      const dx: number = screenX - this.lastX
      const dy: number = screenY - this.lastY
      const layer: WordLayer | undefined = this.getCurrentLayer()
      if (layer) {
        for (const n of layer.nodes) {
          if (n.id === this.draggingNodeId) {
            this.emitNodePositionChange(n.id, n.x + dx / this.camera.scale, n.y + dy / this.camera.scale)
            break
          }
        }
      }
    } else if (this.isPanning) {
      const dx: number = screenX - this.lastX
      const dy: number = screenY - this.lastY
      this.camera.x += dx
      this.camera.y += dy
      this.emitCameraCha