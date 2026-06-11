import { Layer, Point, Viewport, WordEdge, WordNode, Workspace } from '../models/GraphModels'
import { COLORS, MAX_ZOOM, MIN_ZOOM, NODE_HEIGHT, NODE_RADIUS, ZOOM_STEP } from '../constants/AppConstants'
import { getNodeWidth, screenToWorld } from '../utils/GeometryUtil'

@Component
export struct GraphCanvas {
  @Prop workspace: Workspace = {
    version: '1.0.0',
    appName: 'WordNet Pro',
    activeLayerId: '',
    layers: [],
    settings: {
      autoSave: true,
      showGrid: false,
      defaultZoom: 1,
      confirmBeforeDelete: true,
      confirmBeforeClear: true
    },
    createdAt: '',
    updatedAt: ''
  }
  @Prop activeLayerId: string = ''
  @Prop selectedNodeIds: string[] = []
  @Prop highlightedNodeId: string = ''
  @Prop connectingFromNodeId: string = ''
  @Prop showGrid: boolean = false
  onSelectSingle: (nodeId: string) => void = (id: string) => {}
  onSelectMultiple: (nodeIds: string[]) => void = (ids: string[]) => {}
  onClearSelection: () => void = () => {}
  onNodePositionChange: (nodeId: string, x: number, y: number) => void = (id: string, x: number, y: number) => {}
  onMoveSelectedNodes: (deltaX: number, deltaY: number) => void = (dx: number, dy: number) => {}
  onViewportChange: (x: number, y: number, zoom: number) => void = (x: number, y: number, z: number) => {}
  onCompleteConnect: (nodeId: string) => void = (id: string) => {}
  onCanvasReady: (width: number, height: number) => void = (w: number, h: number) => {}

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private canvasWidth: number = 0
  private canvasHeight: number = 0
  private draggingNodeId: string = ''
  private isDraggingCanvas: boolean = false
  private isSelectingRect: boolean = false
  private lastPoint: Point = { x: 0, y: 0 }
  private selectionStart: Point = { x: 0, y: 0 }
  private selectionEnd: Point = { x: 0, y: 0 }
  private selectedSet: Set<string> = new Set<string>()
  private activeLayerRef: Layer | undefined = undefined

  aboutToAppear(): void {
    this.syncSelectedSet()
  }

  private syncSelectedSet(): void {
    const newSet: Set<string> = new Set<string>()
    for (const id of this.selectedNodeIds) {
      newSet.add(id)
    }
    this.selectedSet = newSet
  }

  private getActiveLayer(): Layer | undefined {
    for (const l of this.workspace.layers) {
      if (l.id === this.activeLayerId) {
        return l
      }
    }
    return undefined
  }

  private getViewport(): Viewport {
    const layer: Layer | undefined = this.getActiveLayer()
    if (layer) {
      return layer.viewport
    }
    return { x: 0, y: 0, zoom: 1 }
  }

  private redraw(): void {
    const ctx: CanvasRenderingContext2D = this.context
    if (!ctx) {
      return
    }

    const w: number = this.canvasWidth
    const h: number = this.canvasHeight

    ctx.clearRect(0, 0, w, h)

    ctx.fillStyle = COLORS.pageBg
    ctx.fillRect(0, 0, w, h)

    const layer: Layer | undefined = this.getActiveLayer()
    if (!layer || layer.nodes.length === 0) {
      ctx.fillStyle = COLORS.textSecondary
      ctx.font = '16px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText('暂无单词节点', w / 2, h / 2 - 12)
      ctx.font = '13px sans-serif'
      ctx.fillText('请从右侧/下方添加第一个单词', w / 2, h / 2 + 12)
      return
    }

    const viewport: Viewport = layer.viewport

    if (this.showGrid) {
      this.drawGrid(ctx, w, h, viewport)
    }

    this.drawEdges(ctx, layer.edges, layer.nodes, viewport)
    this.drawNodes(ctx, layer.nodes, viewport)

    if (this.connectingFromNodeId.length > 0) {
      ctx.fillStyle = COLORS.primary
      ctx.font = '12px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText('点击目标节点完成连接', w / 2, 30)
    }

    if (this.isSelectingRect) {
      this.drawSelectionRect(ctx, viewport)
    }
  }

  private drawGrid(ctx: CanvasRenderingContext2D, w: number, h: number, viewport: Viewport): void {
    const gridSize: number = 40 * viewport.zoom
    const offsetX: number = viewport.x % gridSize
    const offsetY: number = viewport.y % gridSize

    ctx.strokeStyle = '#E2E8F0'
    ctx.lineWidth = 0.5
    ctx.beginPath()

    for (let x: number = offsetX; x < w; x += gridSize) {
      ctx.moveTo(x, 0)
      ctx.lineTo(x, h)
    }
    for (let y: number = offsetY; y < h; y += gridSize) {
      ctx.moveTo(0, y)
      ctx.lineTo(w, y)
    }
    ctx.stroke()
  }

  private drawEdges(ctx: CanvasRenderingContext2D, edges: WordEdge[], nodes: WordNode[],
    viewport: Viewport): void {
    const nodeMap: Map<string, WordNode> = new Map<string, WordNode>()
    for (const node of nodes) {
      nodeMap.set(node.id, node)
    }

    for (const edge of edges) {
      const sourceNode: WordNode | undefined = nodeMap.get(edge.source)
      const targetNode: WordNode | undefined = nodeMap.get(edge.target)
      if (!sourceNode || !targetNode) {
        continue
      }

      const sx: number = sourceNode.x * viewport.zoom + viewport.x
      const sy: number = sourceNode.y * viewport.zoom + viewport.y
      const tx: number = targetNode.x * viewport.zoom + viewport.x
      const ty: number = targetNode.y * viewport.zoom + viewport.y

      const bothSelected: boolean = this.selectedSet.has(edge.source) && this.selectedSet.has(edge.target)

      ctx.beginPath()
      ctx.moveTo(sx, sy)
      ctx.lineTo(tx, ty)
      ctx.strokeStyle = bothSelected ? COLORS.edgeSelected : COLORS.edge
      ctx.lineWidth = bothSelected ? 2 : 1.5
      ctx.stroke()
    }
  }

  private drawNodes(ctx: CanvasRenderingContext2D, nodes: WordNode[], viewport: Viewport): void {
    for (const node of nodes) {
      const screenX: number = node.x * viewport.zoom + viewport.x
      const screenY: number = node.y * viewport.zoom + viewport.y
      const nodeW: number = getNodeWidth(node.label) * viewport.zoom
      const nodeH: number = NODE_HEIGHT * viewport.zoom
      const radius: number = NODE_RADIUS * viewport.zoom

      const left: number = screenX - nodeW / 2
      const top: number = screenY - nodeH / 2

      ctx.beginPath()
      ctx.moveTo(left + radius, top)
      ctx.lineTo(left + nodeW - radius, top)
      ctx.quadraticCurveTo(left + nodeW, top, left + nodeW, top + radius)
      ctx.lineTo(left + nodeW, top + nodeH - radius)
      ctx.quadraticCurveTo(left + nodeW, top + nodeH, left + nodeW - radius, top + nodeH)
      ctx.lineTo(left + radius, top + nodeH)
      ctx.quadraticCurveTo(left, top + nodeH, left, top + nodeH - radius)
      ctx.lineTo(left, top + radius)
      ctx.quadraticCurveTo(left, top, left + radius, top)
      ctx.closePath()

      ctx.fillStyle = COLORS.nodeBg
      ctx.fill()

      const isSelected: boolean = this.selectedSet.has(node.id)
      const isHighlighted: boolean = node.id === this.highlightedNodeId

      if (isHighlighted) {
        ctx.strokeStyle = COLORS.nodeHighlightedBorder
        ctx.lineWidth = 3
      } else if (isSelected) {
        ctx.strokeStyle = COLORS.nodeSelectedBorder
        ctx.lineWidth = 2.5
      } else {
        ctx.strokeStyle = COLORS.nodeBorder
        ctx.lineWidth = 1
      }
      ctx.stroke()

      const fontSize: number = Math.max(11, 14 * viewport.zoom)
      ctx.fillStyle = COLORS.textPrimary
      ctx.font = fontSize + 'px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'

      const maxTextWidth: number = nodeW - 12 * viewport.zoom
      let displayLabel: string = node.label
      const textMetrics: TextMetrics = ctx.measureText(displayLabel)
      if (textMetrics.width > maxTextWidth && maxTextWidth > 0) {
        while (displayLabel.length > 1 && ctx.measureText(displayLabel + '…').width > maxTextWidth) {
          displayLabel = displayLabel.slice(0, -1)
        }
        displayLabel = displayLabel + '…'
      }
      ctx.fillText(displayLabel, screenX, screenY)
    }
  }

  private drawSelectionRect(ctx: CanvasRenderingContext2D, viewport: Viewport): void {
    const startScreenX: number = this.selectionStart.x * viewport.zoom + viewport.x
    const startScreenY: number = this.selectionStart.y * viewport.zoom + viewport.y
    const endScreenX: number = this.selectionEnd.x * viewport.zoom + viewport.x
    const endScreenY: number = this.selectionEnd.y * viewport.zoom + viewport.y

    const left: number = Math.min(startScreenX, endScreenX)
    const top: number = Math.min(startScreenY, endScreenY)
    const width: number = Math.abs(endScreenX - startScreenX)
    const height: number = Math.abs(endScreenY - startScreenY)

    ctx.fillStyle = COLORS.selectionFill
    ctx.fillRect(left, top, width, height)
    ctx.strokeStyle = COLORS.selectionStroke
    ctx.lineWidth = 1
    ctx.setLineDash([4, 4])
    ctx.strokeRect(left, top, width, height)
    ctx.setLineDash([])
  }

  private hitTestNode(screenX: number, screenY: number, nodes: WordNode[],
    viewport: Viewport): WordNode | undefined {
    for (let i: number = nodes.length - 1; i >= 0; i--) {
      const node: WordNode = nodes[i]
      const nodeScreenX: number = node.x * viewport.zoom + viewport.x
      const nodeScreenY: number = node.y * viewport.zoom + viewport.y
      const nodeW: number = getNodeWidth(node.label) * viewport.zoom
      const nodeH: number = NODE_HEIGHT * viewport.zoom

      const left: number = nodeScreenX - nodeW / 2
      const top: number = nodeScreenY - nodeH / 2

      if (screenX >= left && screenX <= left + nodeW &&
        screenY >= top && screenY <= top + nodeH) {
        return node
      }
    }
    return undefined
  }

  private handlePointerDown(screenX: number, screenY: number): void {
    const layer: Layer | undefined = this.getActiveLayer()
    if (!layer) {
      return
    }

    const viewport: Viewport = layer.viewport
    const hitNode: WordNode | undefined = this.hitTestNode(screenX, screenY, layer.nodes, viewport)
    this.lastPoint = { x: screenX, y: screenY }

    if (hitNode) {
      if (this.connectingFromNodeId.length > 0 && hitNode.id !== this.connectingFromNodeId) {
        this.onCompleteConnect(hitNode.id)
        return
      }

      this.draggingNodeId = hitNode.id
      if (!this.selectedSet.has(hitNode.id)) {
        this.onSelectSingle(hitNode.id)
      }
    } else {
      if (this.connectingFromNodeId.length > 0) {
        return
      }

      this.isDraggingCanvas = true
      this.onClearSelection()
    }
  }

  private handlePointerMove(screenX: number, screenY: number): void {
    const layer: Layer | undefined = this.getActiveLayer()
    if (!layer) {
      return
    }

    const viewport: Viewport = layer.viewport
    const dx: number = screenX - this.lastPoint.x
    const dy: number = screenY - this.lastPoint.y

    if (this.draggingNodeId.length > 0) {
      const worldDx: number = dx / viewport.zoom
      const worldDy: number = dy / viewport.zoom

      if (this.selectedSet.has(this.draggingNodeId) && this.selectedNodeIds.length > 1) {
        this.onMoveSelectedNodes(worldDx, worldDy)
      } else {
        let node: WordNode | undefined = undefined
        for (const n of layer.nodes) {
          if (n.id === this.draggingNodeId) {
            node = n
            break
          }
        }
        if (node) {
          this.onNodePositionChange(this.draggingNodeId, node.x + worldDx, node.y + worldDy)
        }
      }
    } else if (this.isDraggingCanvas) {
      this.onViewportChange(viewport.x + dx, viewport.y + dy, viewport.zoom)
    }

    this.lastPoint = { x: screenX, y: screenY }
  }

  private handlePointerUp(): void {
    this.draggingNodeId = ''
    this.isDraggingCanvas = false
    this.isSelectingRect = false
  }

  private zoomIn(): void {
    const viewport: Viewport = this.getViewport()
    const newZoom: number = Math.min(viewport.zoom + ZOOM_STEP, MAX_ZOOM)
    const cx: number = this.canvasWidth / 2
    const cy: number = this.canvasHeight / 2
    const worldCx: number = (cx - viewport.x) / viewport.zoom
    const worldCy: number = (cy - viewport.y) / viewport.zoom
    const newX: number = cx - worldCx * newZoom
    const newY: number = cy - worldCy * newZoom
    this.onViewportChange(newX, newY, newZoom)
  }

  private zoomOut(): void {
    const viewport: Viewport = this.getViewport()
    const newZoom: number = Math.max(viewport.zoom - ZOOM_STEP, MIN_ZOOM)
    const cx: number = this.canvasWidth / 2
    const cy: number = this.canvasHeight / 2
    const worldCx: number = (cx - viewport.x) / viewport.zoom
    const worldCy: number = (cy - viewport.y) / viewport.zoom
    const newX: number = cx - worldCx * newZoom
    const newY: number = cy - worldCy * newZoom
    this.onViewportChange(newX, newY, newZoom)
  }

  private zoomReset(): void {
    this.onViewportChange(0, 0, 1)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.canvasWidth = this.context.width
          this.canvasHeight = this.context.height
          this.onCanvasReady(this.canvasWidth, this.canvasHeight)
          this.redraw()
        })
        .onAreaChange((_oldVal: Area, newVal: Area) => {
          if ((newVal.width as number) > 0 && (newVal.height as number) > 0) {
            this.canvasWidth = newVal.width as number
            this.canvasHeight = newVal.height as number
            this.redraw()
          }
        })
        .gesture(
          GestureGroup(GestureMode.Parallel,
            PanGesture({ distance: 1 })
              .onActionStart((event: GestureEvent) => {
                this.handlePointerDown(event.fingerList[0].localX, event.fingerList[0].localY)
              })
              .onActionUpdate((event: GestureEvent) => {
                this.handlePointerMove(event.fingerList[0].localX, event.fingerList[0].localY)
              })
              .onActionEnd(() => {
                this.handlePointerUp()
              })
          )
        )

      Column({ space: 6 }) {
        Button('+')
          .type(ButtonType.Circle)
          .width(36)
          .height(36)
          .fontSize(18)
          .backgroundColor(COLORS.panelBg)
          .fontColor(COLORS.textPrimary)
          .shadow({ radius: 4, color: '#1A000000' })
          .onClick(() => {
            this.zoomIn()
          })

        Button('-')
          .type(ButtonType.Circle)
          .width(36)
          .height(36)
          .fontSize(18)
          .backgroundColor(COLORS.panelBg)
          .fontColor(COLORS.textPrimary)
          .shadow({ radius: 4, color: '#1A000000' })
          .onClick(() => {
            this.zoomOut()
          })

        Button('1:1')
          .type(ButtonType.Normal)
          .width(36)
          .height(36)
          .fontSize(10)
          .borderRadius(18)
          .backgroundColor(COLORS.panelBg)
          .fontColor(COLORS.textPrimary)
          .shadow({ radius: 4, color: '#1A000000' })
          .onClick(() => {
            this.zoomReset()
          })
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.pageBg)
    .onAppear(() => {
      this.syncSelectedSet()
    })
  }
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                