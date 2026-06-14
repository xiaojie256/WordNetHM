import { CameraState, WordLayer, WordNode, WordEdge, WorkspaceData } from '../models/GraphModels'
import { createDefaultWorkspace } from '../services/WorkspaceFactory'
import { COLORS, NODE_RADIUS, MIN_SCALE, MAX_SCALE, ZOOM_FACTOR, LONG_PRESS_MS } from '../constants/AppConstants'
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
  private longPressTriggered: boolean = false
  private suppressNextTapAfterLongPress: boolean = false
  private longPressTimer: number = -1
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
    if (!layer) { return }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: layer.nodes, edges: layer.edges,
      nextId: layer.nextId, camera: { x: this.camera.x, y: this.camera.y, scale: this.camera.scale },
      createdAt: layer.createdAt, updatedAt: Date.now()
    }
    const updatedLayers: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id === updatedLayer.id) { updatedLayers.push(updatedLayer) } else { updatedLayers.push(l) }
    }
    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
  }

  private emitNodePositionChange(nodeId: number, x: number, y: number): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) { return }
    const updatedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.id === nodeId) { updatedNodes.push({ id: n.id, word: n.word, x: x, y: y, note: n.note }) } else { updatedNodes.push(n) }
    }
    const updatedLayer: WordLayer = {
      id: layer.id, name: layer.name, nodes: updatedNodes, edges: layer.edges,
      nextId: layer.nextId, camera: layer.camera, createdAt: layer.createdAt, updatedAt: Date.now()
    }
    const updatedLayers: WordLayer[] = []
    for (const l of this.workspace.layers) {
      if (l.id === updatedLayer.id) { updatedLayers.push(updatedLayer) } else { updatedLayers.push(l) }
    }
    this.onWorkspaceChange({
      version: this.workspace.version, appName: this.workspace.appName,
      currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now()
    })
  }

  public zoomIn(): void { this.zoomAtCenter(ZOOM_FACTOR) }
  public zoomOut(): void { this.zoomAtCenter(1 / ZOOM_FACTOR) }
  public resetZoom(): void { this.camera = { x: 0, y: 0, scale: 1 }; this.emitCameraChange(); this.safeRedraw() }

  public fitView(): void {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer || layer.nodes.length === 0) {
      this.camera = { x: this.canvasWidth / 2, y: this.canvasHeight / 2, scale: 1 }
      this.emitCameraChange(); this.safeRedraw(); return
    }
    let minX: number = Infinity, maxX: number = -Infinity, minY: number = Infinity, maxY: number = -Infinity
    for (const n of layer.nodes) {
      if (n.x < minX) { minX = n.x } if (n.x > maxX) { maxX = n.x }
      if (n.y < minY) { minY = n.y } if (n.y > maxY) { maxY = n.y }
    }
    const graphW: number = Math.max(maxX - minX, 120), graphH: number = Math.max(maxY - minY, 120)
    const padding: number = 80
    const scaleX: number = (this.canvasWidth - padding * 2) / graphW, scaleY: number = (this.canvasHeight - padding * 2) / graphH
    const nextScale: number = this.clampScale(Math.min(scaleX, scaleY))
    const centerX: number = (minX + maxX) / 2, centerY: number = (minY + maxY) / 2
    this.camera = { scale: nextScale, x: this.canvasWidth / 2 - centerX * nextScale, y: this.canvasHeight / 2 - centerY * nextScale }
    this.emitCameraChange(); this.safeRedraw()
  }

  private zoomAtCenter(factor: number): void { this.zoomAt(this.canvasWidth / 2, this.canvasHeight / 2, factor) }
  private zoomAt(screenX: number, screenY: number, factor: number): void {
    const before: Point2D = this.toWorld(screenX, screenY)
    const nextScale: number = this.clampScale(this.camera.scale * factor)
    this.camera.scale = nextScale; this.camera.x = screenX - before.x * nextScale; this.camera.y = screenY - before.y * nextScale
    this.emitCameraChange(); this.safeRedraw()
  }

  public selectNode(nodeId: number): void { this.onSelectedNodeChange(nodeId); this.safeRedraw() }
  public highlightNode(nodeId: number): void { this.highlightNodeId = nodeId; this.safeRedraw() }

  private hitTestNode(screenX: number, screenY: number): WordNode | undefined {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) { return undefined }
    const world: Point2D = this.toWorld(screenX, screenY)
    for (let i: number = layer.nodes.length - 1; i >= 0; i--) {
      const node: WordNode = layer.nodes[i]
      const dx: number = node.x - world.x, dy: number = node.y - world.y
      if (Math.sqrt(dx * dx + dy * dy) <= NODE_RADIUS) { return node }
    }
    return undefined
  }

  private resetDragState(): void {
    this.isDraggingNode = false; this.isPanning = false; this.draggingNodeId = -1
  }

  private clearLongPressTimer(): void {
    if (this.longPressTimer !== -1) {
      clearTimeout(this.longPressTimer)
      this.longPressTimer = -1
    }
  }

  private handleBoxSelectDown(screenX: number, screenY: number): boolean {
    if (!this.boxSelectMode) { return false }
    console.info(`[GC] BOX_DOWN x=${screenX.toFixed(0)} y=${screenY.toFixed(0)}`)
    const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY)
    if (hitNode) {
      if (this.selectedNodeIds.includes(hitNode.id)) {
        const worldPoint: Point2D = this.toWorld(screenX, screenY)
        this.isDraggingMultiNodes = true; this.multiDragLastWorldX = worldPoint.x; this.multiDragLastWorldY = worldPoint.y
        return true
      }
      this.onMultiSelectNodes([hitNode.id]); return true
    }
    this.isBoxSelecting = true; this.boxStartX = screenX; this.boxStartY = screenY; this.boxCurrentX = screenX; this.boxCurrentY = screenY
    this.onMultiSelectNodes([]); return true
  }

  private handleBoxSelectMove(screenX: number, screenY: number): boolean {
    if (!this.boxSelectMode) { return false }
    if (this.isBoxSelecting) {
      this.boxCurrentX = screenX; this.boxCurrentY = screenY
      console.info(`[GC] BOX_MOVE x=${screenX.toFixed(0)} y=${screenY.toFixed(0)} w=${Math.abs(this.boxCurrentX - this.boxStartX).toFixed(0)} h=${Math.abs(this.boxCurrentY - this.boxStartY).toFixed(0)}`)
      this.safeRedraw(); return true
    }
    if (this.isDraggingMultiNodes) {
      const worldPoint: Point2D = this.toWorld(screenX, screenY)
      const dx: number = worldPoint.x - this.multiDragLastWorldX, dy: number = worldPoint.y - this.multiDragLastWorldY
      this.multiDragLastWorldX = worldPoint.x; this.multiDragLastWorldY = worldPoint.y
      if (this.selectedNodeIds.length > 0) { this.onMoveSelectedNodes(this.selectedNodeIds, dx, dy) }
      return true
    }
    return false
  }

  private handleBoxSelectUp(): boolean {
    if (!this.boxSelectMode) { return false }
    if (this.isDraggingMultiNodes) { this.isDraggingMultiNodes = false; return true }
    if (!this.isBoxSelecting) { return false }
    const selectedIds: number[] = this.getNodesInSelectionBox()
    this.isBoxSelecting = false; this.safeRedraw()
    this.onMultiSelectNodes(selectedIds)
    if (selectedIds.length > 0) { showToast('已选中 ' + selectedIds.length.toString() + ' 个节点') } else { showToast('未选中节点') }
    return true
  }

  private getNodesInSelectionBox(): number[] {
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer) { return [] }
    const left: number = Math.min(this.boxStartX, this.boxCurrentX), right: number = Math.max(this.boxStartX, this.boxCurrentX)
    const top: number = Math.min(this.boxStartY, this.boxCurrentY), bottom: number = Math.max(this.boxStartY, this.boxCurrentY)
    const topLeftWorld: Point2D = this.toWorld(left, top), bottomRightWorld: Point2D = this.toWorld(right, bottom)
    const worldLeft: number = Math.min(topLeftWorld.x, bottomRightWorld.x), worldRight: number = Math.max(topLeftWorld.x, bottomRightWorld.x)
    const worldTop: number = Math.min(topLeftWorld.y, bottomRightWorld.y), worldBottom: number = Math.max(topLeftWorld.y, bottomRightWorld.y)
    const ids: number[] = []
    for (const node of layer.nodes) {
      if (node.x >= worldLeft && node.x <= worldRight && node.y >= worldTop && node.y <= worldBottom) { ids.push(node.id) }
    }
    return ids
  }

  private drawSelectionBox(ctx: CanvasRenderingContext2D): void {
    if (!this.isBoxSelecting) { return }
    const left: number = Math.min(this.boxStartX, this.boxCurrentX), top: number = Math.min(this.boxStartY, this.boxCurrentY)
    const width: number = Math.abs(this.boxCurrentX - this.boxStartX), height: number = Math.abs(this.boxCurrentY - this.boxStartY)
    if (width < 2 && height < 2) { return }
    ctx.save(); ctx.strokeStyle = COLORS.primary; ctx.lineWidth = 1.5; ctx.setLineDash([6, 4]); ctx.strokeRect(left, top, width, height); ctx.restore()
  }

  private handlePointerDown(screenX: number, screenY: number): void {
    console.info(`[GC] handlePointerDown x=${screenX.toFixed(0)} y=${screenY.toFixed(0)} box=${this.boxSelectMode} longPress=${this.longPressTriggered}`)
    if (this.longPressTriggered) { this.longPressTriggered = false; return }
    if (this.handleBoxSelectDown(screenX, screenY)) { return }
    this.lastX = screenX; this.lastY = screenY
    const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY)
    if (hitNode) {
      if (this.connectingFromId >= 0 && hitNode.id !== this.connectingFromId) { this.completeConnection(hitNode.id); return }
      this.isDraggingNode = true; this.draggingNodeId = hitNode.id; this.dragStartX = screenX; this.dragStartY = screenY
      this.onSelectedNodeChange(hitNode.id)
    } else {
      this.isPanning = true; this.onSelectedNodeChange(-1); this.connectingFromId = -1
    }
    this.safeRedraw()
  }

  private handlePointerMove(screenX: number, screenY: number): void {
    if (this.handleBoxSelectMove(screenX, screenY)) { return }
    if (this.isDraggingNode && !this.longPressTriggered) {
      const dx: number = screenX - this.lastX, dy: number = screenY - this.lastY
      const layer: WordLayer | undefined = this.getCurrentLayer()
      if (layer) { for (const n of layer.nodes) { if (n.id === this.draggingNodeId) { this.emitNodePositionChange(n.id, n.x + dx / this.camera.scale, n.y + dy / this.camera.scale); break } } }
    } else if (this.isPanning) {
      const dx: number = screenX - this.lastX, dy: number = screenY - this.lastY
      this.camera.x += dx; this.camera.y += dy; this.emitCameraChange(); this.safeRedraw()
    }
    this.lastX = screenX; this.lastY = screenY
  }

  private handlePointerUp(): void {
    if (this.handleBoxSelectUp()) { return }
    const wasLongPress: boolean = this.longPressTriggered
    if (wasLongPress) { this.longPressTriggered = false; this.resetDragState(); return }
    this.longPressTriggered = false; this.resetDragState()
  }

  private getTouchDistance(t0: TouchObject, t1: TouchObject): number { return Math.sqrt((t0.x - t1.x) ** 2 + (t0.y - t1.y) ** 2) }
  private zoomToScaleAt(screenX: number, screenY: number, nextScale: number): void {
    const before: Point2D = this.toWorld(screenX, screenY); this.camera.scale = nextScale
    this.camera.x = screenX - before.x * nextScale; this.camera.y = screenY - before.y * nextScale
    this.emitCameraChange(); this.safeRedraw()
  }
  private handlePinchStart(t0: TouchObject, t1: TouchObject): void {
    this.isPinching = true; this.isDraggingNode = false; this.isPanning = false
    this.pinchStartDistance = this.getTouchDistance(t0, t1); this.pinchStartScale = this.camera.scale
    this.pinchCenterX = (t0.x + t1.x) / 2; this.pinchCenterY = (t0.y + t1.y) / 2
  }
  private handlePinchUpdate(t0: TouchObject, t1: TouchObject): void {
    if (!this.isPinching) { return }
    const currentDistance: number = this.getTouchDistance(t0, t1)
    if (this.pinchStartDistance <= 0) { return }
    this.zoomToScaleAt(this.pinchCenterX, this.pinchCenterY, this.clampScale(this.pinchStartScale * (currentDistance / this.pinchStartDistance)))
  }
  private handlePinchEnd(): void { this.isPinching = false }

  public startConnectFromSelected(): void { if (this.selectedNodeId >= 0) { this.connectingFromId = this.selectedNodeId; this.safeRedraw() } }
  private onStartConnectChange(): void { if (this.shouldStartConnect) { this.shouldStartConnect = false; this.startConnectFromSelected() } }

  private completeConnection(targetId: number): void {
    if (this.connectingFromId < 0 || this.connectingFromId === targetId) { this.connectingFromId = -1; this.safeRedraw(); return }
    const layer: WordLayer | undefined = this.getCurrentLayer(); if (!layer) { return }
    for (const e of layer.edges) {
      if ((e.from === this.connectingFromId && e.to === targetId) || (e.from === targetId && e.to === this.connectingFromId)) { this.connectingFromId = -1; this.safeRedraw(); return }
    }
    const updatedEdges: WordEdge[] = [...layer.edges, { from: this.connectingFromId, to: targetId }]
    const updatedLayer: WordLayer = { id: layer.id, name: layer.name, nodes: layer.nodes, edges: updatedEdges, nextId: layer.nextId, camera: layer.camera, createdAt: layer.createdAt, updatedAt: Date.now() }
    const updatedLayers: WordLayer[] = []
    for (const l of this.workspace.layers) { if (l.id === updatedLayer.id) { updatedLayers.push(updatedLayer) } else { updatedLayers.push(l) } }
    this.connectingFromId = -1
    this.onWorkspaceChange({ version: this.workspace.version, appName: this.workspace.appName, currentLayerId: this.workspace.currentLayerId, layers: updatedLayers, updatedAt: Date.now() })
  }

  private redraw(): void {
    const ctx: CanvasRenderingContext2D = this.context, w: number = this.canvasWidth, h: number = this.canvasHeight
    ctx.clearRect(0, 0, w, h); ctx.fillStyle = COLORS.pageBg; ctx.fillRect(0, 0, w, h)
    const layer: WordLayer | undefined = this.getCurrentLayer()
    if (!layer || layer.nodes.length === 0) {
      ctx.fillStyle = COLORS.textSecondary; ctx.font = '16px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'
      ctx.fillText('暂无单词节点', w / 2, h / 2 - 12); ctx.font = '13px sans-serif'; ctx.fillText('点击右上角 ⚙ 添加第一个单词', w / 2, h / 2 + 12); return
    }
    ctx.save(); ctx.translate(this.camera.x, this.camera.y); ctx.scale(this.camera.scale, this.camera.scale)
    for (const edge of layer.edges) { this.drawEdge(ctx, edge, layer.nodes) }
    for (const node of layer.nodes) { this.drawNode(ctx, node) }
    ctx.restore()
    this.drawSelectionBox(ctx)
    if (this.connectingFromId >= 0) { ctx.fillStyle = COLORS.primary; ctx.font = '13px sans-serif'; ctx.textAlign = 'center'; ctx.fillText('点击目标节点完成连接', w / 2, 30) }
  }

  private drawEdge(ctx: CanvasRenderingContext2D, edge: WordEdge, nodes: WordNode[]): void {
    let fromNode: WordNode | undefined, toNode: WordNode | undefined
    for (const n of nodes) { if (n.id === edge.from) { fromNode = n } if (n.id === edge.to) { toNode = n } }
    if (!fromNode || !toNode) { return }
    ctx.beginPath(); ctx.moveTo(fromNode.x, fromNode.y); ctx.lineTo(toNode.x, toNode.y); ctx.strokeStyle = COLORS.edgeColor; ctx.lineWidth = 1.5; ctx.stroke()
  }

  private drawNode(ctx: CanvasRenderingContext2D, node: WordNode): void {
    const isSelected: boolean = node.id === this.selectedNodeId || node.id === this.highlightNodeId
    const isMultiSelected: boolean = this.selectedNodeIds.includes(node.id)
    ctx.beginPath(); ctx.arc(node.x, node.y, NODE_RADIUS, 0, Math.PI * 2)
    ctx.fillStyle = (isSelected || isMultiSelected) ? COLORS.nodeHighlight : COLORS.nodeBg; ctx.fill()
    ctx.strokeStyle = isSelected ? COLORS.nodeSelectedBorder : COLORS.nodeBorder; ctx.lineWidth = isSelected ? 3 : 1.5; ctx.stroke()
    if (isMultiSelected && !isSelected) {
      ctx.beginPath(); ctx.arc(node.x, node.y, NODE_RADIUS + 4, 0, Math.PI * 2); ctx.strokeStyle = COLORS.primary; ctx.lineWidth = 2.5
      ctx.setLineDash([4, 3]); ctx.stroke(); ctx.setLineDash([])
    }
    const fontSize: number = Math.max(11, Math.min(15, 12 / this.camera.scale))
    ctx.fillStyle = COLORS.textPrimary; ctx.font = `bold ${fontSize}px sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'
    let label: string = node.word; const maxWidth: number = NODE_RADIUS * 1.6; const metrics: TextMetrics = ctx.measureText(label)
    if (metrics.width > maxWidth && maxWidth > 0) { while (label.length > 1 && ctx.measureText(label + '…').width > maxWidth) { label = label.slice(0, -1) }; label = label + '…' }
    ctx.fillText(label, node.x, node.y)
    if (node.note && node.note.length > 0) { ctx.fillStyle = COLORS.noteDot; ctx.beginPath(); ctx.arc(node.x + 22, node.y - 22, 5, 0, Math.PI * 2); ctx.fill() }
  }

  build() {
    Stack() {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.canvasWidth = this.context.width; this.canvasHeight = this.context.height; this.isCanvasReady = true
          this.syncCameraFromLayer(); this.safeRedraw(); this.onViewportChange(this.canvasWidth, this.canvasHeight)
        })
        .onAreaChange((_oldVal: Area, newVal: Area) => {
          const newW: number = newVal.width as number, newH: number = newVal.height as number
          if (newW > 0 && newH > 0) { this.canvasWidth = newW; this.canvasHeight = newH; this.safeRedraw(); this.onViewportChange(newW, newH) }
        })
        .gesture(
          GestureGroup(GestureMode.Parallel,
            LongPressGesture({ duration: LONG_PRESS_MS })
              .onAction((event: GestureEvent) => {
                const screenX: number = event.fingerList[0].localX, screenY: number = event.fingerList[0].localY
                console.info(`[GC] LONG_PRESS x=${screenX.toFixed(0)} y=${screenY.toFixed(0)}`)
                const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY)
                if (!hitNode) { return }
                const menuX: number = Math.max(10, Math.min(screenX, this.canvasWidth - 140))
                const menuY: number = Math.max(10, Math.min(screenY, this.canvasHeight - 130))
                this.longPressTriggered = true
                this.suppressNextTapAfterLongPress = true
                this.isDraggingNode = false
                this.isPanning = false
                this.draggingNodeId = -1
                console.info(`[GC] LONG_PRESS node=${hitNode.id} x=${menuX.toFixed(0)} y=${menuY.toFixed(0)}`)
                this.onLongPressNode(hitNode.id, menuX, menuY)
              }),
            TapGesture({ count: 1 })
              .onAction((event: GestureEvent) => {
                if (this.suppressNextTapAfterLongPress) {
                  console.info('[GC] TAP ignored after long press')
                  this.suppressNextTapAfterLongPress = false
                  this.longPressTriggered = false
                  return
                }
                if (this.longPressTriggered) {
                  console.info('[GC] TAP ignored because longPressTriggered=true')
                  this.longPressTriggered = false
                  return
                }
                const screenX: number = event.fingerList[0].localX, screenY: number = event.fingerList[0].localY
                console.info(`[GC] TAP x=${screenX.toFixed(0)} y=${screenY.toFixed(0)} box=${this.boxSelectMode}`)
                if (this.boxSelectMode) { return }
                const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY)
                if (hitNode) { this.onSelectedNodeChange(hitNode.id) } else { this.onSelectedNodeChange(-1) }
                this.safeRedraw()
              }),
            PanGesture({ distance: 1 })
              .onActionStart((event: GestureEvent) => {
                const screenX: number = event.fingerList[0].localX, screenY: number = event.fingerList[0].localY
                console.info(`[GC] PAN start x=${screenX.toFixed(0)} y=${screenY.toFixed(0)} box=${this.boxSelectMode}`)
                this.handlePointerDown(screenX, screenY)
              })
              .onActionUpdate((event: GestureEvent) => {
                const screenX: number = event.fingerList[0].localX, screenY: number = event.fingerList[0].localY
                if (this.boxSelectMode || this.isDraggingNode || this.isPanning) {
                  console.info(`[GC] PAN update x=${screenX.toFixed(0)} y=${screenY.toFixed(0)} drag=${this.isDraggingNode} pan=${this.isPanning} boxSel=${this.isBoxSelecting}`)
                }
                this.handlePointerMove(screenX, screenY)
              })
              .onActionEnd(() => {
                console.info(`[GC] PAN end drag=${this.isDraggingNode} pan=${this.isPanning} boxSel=${this.isBoxSelecting}`)
                this.handlePointerUp()
              })
          )
        )
        .onTouch((event: TouchEvent) => {
          if (event.touches.length === 2) {
            const t0: TouchObject = event.touches[0], t1: TouchObject = event.touches[1]
            if (event.type === TouchType.Down) { this.handlePinchStart(t0, t1) }
            else if (event.type === TouchType.Move) { this.handlePinchUpdate(t0, t1) }
            else if (event.type === TouchType.Up) { this.handlePinchEnd() }
          } else if (event.type === TouchType.Up && this.isPinching) { this.handlePinchEnd() }
        })
        .onMouse((event: MouseEvent) => {
          const screenX: number = event.x, screenY: number = event.y
          console.info(`[GC] MOUSE action=${event.action} button=${event.button} x=${screenX.toFixed(0)} y=${screenY.toFixed(0)} box=${this.boxSelectMode}`)
          if (event.action === MouseAction.Move) { if (this.boxSelectMode) { this.handlePointerMove(screenX, screenY) }; return }
          if (event.action === MouseAction.Press) {
            if (this.boxSelectMode) { this.handlePointerDown(screenX, screenY); return }
            const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY)
            if (event.button === MouseButton.Right) {
              if (hitNode) {
                const menuX: number = Math.max(10, Math.min(screenX, this.canvasWidth - 140))
                const menuY: number = Math.max(10, Math.min(screenY, this.canvasHeight - 130))
                this.clearLongPressTimer()
                this.longPressTriggered = true
                this.suppressNextTapAfterLongPress = true
                this.isDraggingNode = false
                this.isPanning = false
                this.draggingNodeId = -1
                this.onLongPressNode(hitNode.id, menuX, menuY)
              }
              return
            }
            if (event.button === MouseButton.Left) {
              if (hitNode) { this.onSelectedNodeChange(hitNode.id) }
            }
          }
          if (event.action === MouseAction.Release) { if (this.boxSelectMode) { this.handlePointerUp() } }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.pageBg)
  }
}
