import { Layer, SearchResult, Viewport, WordEdge, WordNode, Workspace } from '../models/GraphModels'
import { createEdge, createLayer, createNode } from './WorkspaceFactory'
import { makeEdgeKey } from '../utils/GeometryUtil'
import { nowIso } from '../utils/TimeUtil'
import { generateId } from '../utils/IdUtil'

function cloneNode(n: WordNode): WordNode {
  const result: WordNode = {
    id: n.id,
    label: n.label,
    x: n.x,
    y: n.y,
    note: n.note,
    style: { color: n.style.color, size: n.style.size },
    createdAt: n.createdAt,
    updatedAt: n.updatedAt
  }
  return result
}

function cloneEdge(e: WordEdge): WordEdge {
  const result: WordEdge = {
    id: e.id,
    source: e.source,
    target: e.target,
    relationType: e.relationType,
    label: e.label,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt
  }
  return result
}

function cloneViewport(v: Viewport): Viewport {
  const result: Viewport = { x: v.x, y: v.y, zoom: v.zoom }
  return result
}

function cloneLayer(l: Layer): Layer {
  const clonedNodes: WordNode[] = []
  for (const n of l.nodes) {
    clonedNodes.push(cloneNode(n))
  }
  const clonedEdges: WordEdge[] = []
  for (const e of l.edges) {
    clonedEdges.push(cloneEdge(e))
  }
  const result: Layer = {
    id: l.id,
    name: l.name,
    nodes: clonedNodes,
    edges: clonedEdges,
    viewport: cloneViewport(l.viewport),
    createdAt: l.createdAt,
    updatedAt: l.updatedAt
  }
  return result
}

function cloneWorkspace(ws: Workspace): Workspace {
  const clonedLayers: Layer[] = []
  for (const l of ws.layers) {
    clonedLayers.push(cloneLayer(l))
  }
  const result: Workspace = {
    version: ws.version,
    appName: ws.appName,
    activeLayerId: ws.activeLayerId,
    layers: clonedLayers,
    settings: {
      autoSave: ws.settings.autoSave,
      showGrid: ws.settings.showGrid,
      defaultZoom: ws.settings.defaultZoom,
      confirmBeforeDelete: ws.settings.confirmBeforeDelete,
      confirmBeforeClear: ws.settings.confirmBeforeClear
    },
    createdAt: ws.createdAt,
    updatedAt: ws.updatedAt
  }
  return result
}

function buildUpdatedLayers(layers: Layer[], targetLayerId: string, updatedLayer: Layer): Layer[] {
  const result: Layer[] = []
  for (const l of layers) {
    if (l.id === targetLayerId) {
      result.push(updatedLayer)
    } else {
      result.push(l)
    }
  }
  return result
}

function buildUpdatedWorkspace(ws: Workspace, layers: Layer[], extra?: PartialWorkspace): Workspace {
  const result: Workspace = {
    version: ws.version,
    appName: ws.appName,
    activeLayerId: extra?.activeLayerId ?? ws.activeLayerId,
    layers: layers,
    settings: ws.settings,
    createdAt: ws.createdAt,
    updatedAt: extra?.updatedAt ?? ws.updatedAt
  }
  return result
}

interface PartialWorkspace {
  activeLayerId?: string
  updatedAt?: string
}

export class GraphService {
  static getActiveLayer(workspace: Workspace): Layer | undefined {
    for (const l of workspace.layers) {
      if (l.id === workspace.activeLayerId) {
        return l
      }
    }
    return undefined
  }

  static addNode(workspace: Workspace, label: string, x: number, y: number): Workspace {
    const trimmedLabel: string = label.trim()
    if (trimmedLabel.length === 0) {
      return workspace
    }

    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const lowerLabel: string = trimmedLabel.toLowerCase()
    let duplicateFound: boolean = false
    for (const n of layer.nodes) {
      if (n.label.toLowerCase() === lowerLabel) {
        duplicateFound = true
        break
      }
    }
    if (duplicateFound) {
      return workspace
    }

    const newNode: WordNode = createNode(trimmedLabel, x, y)
    const updatedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      updatedNodes.push(n)
    }
    updatedNodes.push(newNode)

    const updatedLayer: Layer = {
      id: layer.id,
      name: layer.name,
      nodes: updatedNodes,
      edges: layer.edges,
      viewport: layer.viewport,
      createdAt: layer.createdAt,
      updatedAt: nowIso()
    }

    const updatedLayers: Layer[] = buildUpdatedLayers(workspace.layers, layer.id, updatedLayer)
    return buildUpdatedWorkspace(workspace, updatedLayers, { updatedAt: nowIso() })
  }

  static renameNode(workspace: Workspace, nodeId: string, label: string): Workspace {
    const trimmedLabel: string = label.trim()
    if (trimmedLabel.length === 0) {
      return workspace
    }

    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const lowerLabel: string = trimmedLabel.toLowerCase()
    let conflictFound: boolean = false
    for (const n of layer.nodes) {
      if (n.id !== nodeId && n.label.toLowerCase() === lowerLabel) {
        conflictFound = true
        break
      }
    }
    if (conflictFound) {
      return workspace
    }

    const updatedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.id === nodeId) {
        updatedNodes.push({
          id: n.id,
          label: trimmedLabel,
          x: n.x,
          y: n.y,
          note: n.note,
          style: n.style,
          createdAt: n.createdAt,
          updatedAt: nowIso()
        })
      } else {
        updatedNodes.push(n)
      }
    }

    const updatedLayer: Layer = {
      id: layer.id,
      name: layer.name,
      nodes: updatedNodes,
      edges: layer.edges,
      viewport: layer.viewport,
      createdAt: layer.createdAt,
      updatedAt: nowIso()
    }

    const updatedLayers: Layer[] = buildUpdatedLayers(workspace.layers, layer.id, updatedLayer)
    return buildUpdatedWorkspace(workspace, updatedLayers, { updatedAt: nowIso() })
  }

  static deleteNodes(workspace: Workspace, nodeIds: string[]): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const idSet: Set<string> = new Set<string>(nodeIds)
    const filteredNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (!idSet.has(n.id)) {
        filteredNodes.push(n)
      }
    }

    const filteredEdges: WordEdge[] = []
    for (const e of layer.edges) {
      if (!idSet.has(e.source) && !idSet.has(e.target)) {
        filteredEdges.push(e)
      }
    }

    const updatedLayer: Layer = {
      id: layer.id,
      name: layer.name,
      nodes: filteredNodes,
      edges: filteredEdges,
      viewport: layer.viewport,
      createdAt: layer.createdAt,
      updatedAt: nowIso()
    }

    const updatedLayers: Layer[] = buildUpdatedLayers(workspace.layers, layer.id, updatedLayer)
    return buildUpdatedWorkspace(workspace, updatedLayers, { updatedAt: nowIso() })
  }

  static updateNodePosition(workspace: Workspace, nodeId: string, x: number, y: number): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const updatedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.id === nodeId) {
        updatedNodes.push({
          id: n.id,
          label: n.label,
          x: x,
          y: y,
          note: n.note,
          style: n.style,
          createdAt: n.createdAt,
          updatedAt: nowIso()
        })
      } else {
        updatedNodes.push(n)
      }
    }

    const updatedLayer: Layer = {
      id: layer.id,
      name: layer.name,
      nodes: updatedNodes,
      edges: layer.edges,
      viewport: layer.viewport,
      createdAt: layer.createdAt,
      updatedAt: nowIso()
    }

    const updatedLayers: Layer[] = buildUpdatedLayers(workspace.layers, layer.id, updatedLayer)
    return buildUpdatedWorkspace(workspace, updatedLayers, { updatedAt: nowIso() })
  }

  static moveNodes(workspace: Workspace, nodeIds: string[], deltaX: number, deltaY: number): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const idSet: Set<string> = new Set<string>(nodeIds)
    const updatedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (idSet.has(n.id)) {
        updatedNodes.push({
          id: n.id,
          label: n.label,
          x: n.x + deltaX,
          y: n.y + deltaY,
          note: n.note,
          style: n.style,
          createdAt: n.createdAt,
          updatedAt: nowIso()
        })
      } else {
        updatedNodes.push(n)
      }
    }

    const updatedLayer: Layer = {
      id: layer.id,
      name: layer.name,
      nodes: updatedNodes,
      edges: layer.edges,
      viewport: layer.viewport,
      createdAt: layer.createdAt,
      updatedAt: nowIso()
    }

    const updatedLayers: Layer[] = buildUpdatedLayers(workspace.layers, layer.id, updatedLayer)
    return buildUpdatedWorkspace(workspace, updatedLayers, { updatedAt: nowIso() })
  }

  static updateNodeNote(workspace: Workspace, nodeId: string, note: string): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const updatedNodes: WordNode[] = []
    for (const n of layer.nodes) {
      if (n.id === nodeId) {
        updatedNodes.push({
          id: n.id,
          label: n.label,
          x: n.x,
          y: n.y,
          note: note,
          style: n.style,
          createdAt: n.createdAt,
          updatedAt: nowIso()
        })
      } else {
        updatedNodes.push(n)
      }
    }

    const updatedLayer: Layer = {
      id: layer.id,
      name: layer.name,
      nodes: updatedNodes,
      edges: layer.edges,
      viewport: layer.viewport,
      createdAt: layer.createdAt,
      updatedAt: nowIso()
    }

    const updatedLayers: Layer[] = buildUpdatedLayers(workspace.layers, layer.id, updatedLayer)
    return buildUpdatedWorkspace(workspace, updatedLayers, { updatedAt: nowIso() })
  }

  static connectNodes(workspace: Workspace, sourceId: string, targetId: string): Workspace {
    if (sourceId === targetId) {
      return workspace
    }

    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const key: string = makeEdgeKey(sourceId, targetId)
    let exists: boolean = false
    for (const e of layer.edges) {
      if (makeEdgeKey(e.source, e.target) === key) {
        exists = true
        break
      }
    }
    if (exists) {
      return workspace
    }

    let sourceExists: boolean = false
    let targetExists: boolean = false
    for (const n of layer.nodes) {
      if (n.id === sourceId) {
        sourceExists = true
      }
      if (n.id === targetId) {
        targetExists = true
      }
    }
    if (!sourceExists || !targetExists) {
      return workspace
    }

    const newEdge: WordEdge = createEdge(sourceId, targetId)
    const updatedEdges: WordEdge[] = []
    for (const e of layer.edges) {
      updatedEdges.push(e)
    }
    updatedEdges.push(newEdge)

    const updatedLayer: Layer = {
      id: layer.id,
      name: layer.name,
      nodes: layer.nodes,
      edges: updatedEdges,
      viewport: layer.viewport,
      createdAt: layer.createdAt,
      updatedAt: nowIso()
    }

    const updatedLayers: Layer[] = buildUpdatedLayers(workspace.layers, layer.id, updatedLayer)
    return buildUpdatedWorkspace(workspace, updatedLayers, { updatedAt: nowIso() })
  }

  static disconnectNodes(workspace: Workspace, sourceId: string, targetId: string): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const key: string = makeEdgeKey(sourceId, targetId)
    const filteredEdges: WordEdge[] = []
    for (const e of layer.edges) {
      if (makeEdgeKey(e.source, e.target) !== key) {
        filteredEdges.push(e)
      }
    }

    const updatedLayer: Layer = {
      id: layer.id,
      name: layer.name,
      nodes: layer.nodes,
      edges: filteredEdges,
      viewport: layer.viewport,
      createdAt: layer.createdAt,
      updatedAt: nowIso()
    }

    const updatedLayers: Layer[] = buildUpdatedLayers(workspace.layers, layer.id, updatedLayer)
    return buildUpdatedWorkspace(workspace, updatedLayers, { updatedAt: nowIso() })
  }

  static connectAllSelected(workspace: Workspace, nodeIds: string[]): Workspace {
    if (nodeIds.length < 2) {
      return workspace
    }

    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const existingKeys: Set<string> = new Set<string>()
    for (const e of layer.edges) {
      existingKeys.add(makeEdgeKey(e.source, e.target))
    }

    const newEdges: WordEdge[] = []
    for (let i: number = 0; i < nodeIds.length; i++) {
      for (let j: number = i + 1; j < nodeIds.length; j++) {
        const key: string = makeEdgeKey(nodeIds[i], nodeIds[j])
        if (!existingKeys.has(key)) {
          newEdges.push(createEdge(nodeIds[i], nodeIds[j]))
          existingKeys.add(key)
        }
      }
    }

    if (newEdges.length === 0) {
      return workspace
    }

    const updatedEdges: WordEdge[] = []
    for (const e of layer.edges) {
      updatedEdges.push(e