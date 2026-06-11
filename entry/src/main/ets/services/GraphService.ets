import { Layer, SearchResult, WordEdge, WordNode, Workspace } from '../models/GraphModels'
import { createEdge, createLayer, createNode } from './WorkspaceFactory'
import { makeEdgeKey } from '../utils/GeometryUtil'
import { nowIso } from '../utils/TimeUtil'
import { generateId } from '../utils/IdUtil'
import { DEFAULT_LAYER_NAME } from '../constants/AppConstants'

export class GraphService {
  static getActiveLayer(workspace: Workspace): Layer | undefined {
    return workspace.layers.find((l: Layer) => l.id === workspace.activeLayerId)
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
    const duplicate: WordNode | undefined = layer.nodes.find(
      (n: WordNode) => n.label.toLowerCase() === lowerLabel
    )
    if (duplicate) {
      return workspace
    }

    const newNode: WordNode = createNode(trimmedLabel, x, y)
    const updatedNodes: WordNode[] = [...layer.nodes, newNode]
    const updatedLayer: Layer = {
      ...layer,
      nodes: updatedNodes,
      updatedAt: nowIso()
    }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return {
      ...workspace,
      layers: updatedLayers,
      updatedAt: nowIso()
    }
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
    const conflict: WordNode | undefined = layer.nodes.find(
      (n: WordNode) => n.id !== nodeId && n.label.toLowerCase() === lowerLabel
    )
    if (conflict) {
      return workspace
    }

    const updatedNodes: WordNode[] = layer.nodes.map((n: WordNode) => {
      if (n.id === nodeId) {
        return { ...n, label: trimmedLabel, updatedAt: nowIso() } as WordNode
      }
      return n
    })
    const updatedLayer: Layer = { ...layer, nodes: updatedNodes, updatedAt: nowIso() }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
  }

  static deleteNodes(workspace: Workspace, nodeIds: string[]): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const idSet: Set<string> = new Set<string>(nodeIds)
    const filteredNodes: WordNode[] = layer.nodes.filter(
      (n: WordNode) => !idSet.has(n.id)
    )
    const filteredEdges: WordEdge[] = layer.edges.filter(
      (e: WordEdge) => !idSet.has(e.source) && !idSet.has(e.target)
    )
    const updatedLayer: Layer = {
      ...layer,
      nodes: filteredNodes,
      edges: filteredEdges,
      updatedAt: nowIso()
    }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
  }

  static updateNodePosition(workspace: Workspace, nodeId: string, x: number, y: number): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const updatedNodes: WordNode[] = layer.nodes.map((n: WordNode) => {
      if (n.id === nodeId) {
        return { ...n, x: x, y: y, updatedAt: nowIso() } as WordNode
      }
      return n
    })
    const updatedLayer: Layer = { ...layer, nodes: updatedNodes, updatedAt: nowIso() }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
  }

  static moveNodes(workspace: Workspace, nodeIds: string[], deltaX: number, deltaY: number): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const idSet: Set<string> = new Set<string>(nodeIds)
    const updatedNodes: WordNode[] = layer.nodes.map((n: WordNode) => {
      if (idSet.has(n.id)) {
        return { ...n, x: n.x + deltaX, y: n.y + deltaY, updatedAt: nowIso() } as WordNode
      }
      return n
    })
    const updatedLayer: Layer = { ...layer, nodes: updatedNodes, updatedAt: nowIso() }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
  }

  static updateNodeNote(workspace: Workspace, nodeId: string, note: string): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const updatedNodes: WordNode[] = layer.nodes.map((n: WordNode) => {
      if (n.id === nodeId) {
        return { ...n, note: note, updatedAt: nowIso() } as WordNode
      }
      return n
    })
    const updatedLayer: Layer = { ...layer, nodes: updatedNodes, updatedAt: nowIso() }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
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
    const exists: boolean = layer.edges.some(
      (e: WordEdge) => makeEdgeKey(e.source, e.target) === key
    )
    if (exists) {
      return workspace
    }

    const sourceExists: boolean = layer.nodes.some((n: WordNode) => n.id === sourceId)
    const targetExists: boolean = layer.nodes.some((n: WordNode) => n.id === targetId)
    if (!sourceExists || !targetExists) {
      return workspace
    }

    const newEdge: WordEdge = createEdge(sourceId, targetId)
    const updatedEdges: WordEdge[] = [...layer.edges, newEdge]
    const updatedLayer: Layer = { ...layer, edges: updatedEdges, updatedAt: nowIso() }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
  }

  static disconnectNodes(workspace: Workspace, sourceId: string, targetId: string): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const key: string = makeEdgeKey(sourceId, targetId)
    const filteredEdges: WordEdge[] = layer.edges.filter(
      (e: WordEdge) => makeEdgeKey(e.source, e.target) !== key
    )
    const updatedLayer: Layer = { ...layer, edges: filteredEdges, updatedAt: nowIso() }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
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
    for (let i = 0; i < nodeIds.length; i++) {
      for (let j = i + 1; j < nodeIds.length; j++) {
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

    const updatedEdges: WordEdge[] = [...layer.edges, ...newEdges]
    const updatedLayer: Layer = { ...layer, edges: updatedEdges, updatedAt: nowIso() }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
  }

  static disconnectSelected(workspace: Workspace, nodeIds: string[]): Workspace {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer) {
      return workspace
    }

    const idSet: Set<string> = new Set<string>(nodeIds)
    const filteredEdges: WordEdge[] = layer.edges.filter(
      (e: WordEdge) => !(idSet.has(e.source) && idSet.has(e.target))
    )
    const updatedLayer: Layer = { ...layer, edges: filteredEdges, updatedAt: nowIso() }
    const updatedLayers: Layer[] = workspace.layers.map(
      (l: Layer) => l.id === layer.id ? updatedLayer : l
    )
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
  }

  static createLayer(workspace: Workspace): Workspace {
    const layerCount: number = workspace.layers.length
    const newName: string = `图层 ${layerCount + 1}`
    const newLayer: Layer = createLayer(newName)
    const updatedLayers: Layer[] = [...workspace.layers, newLayer]
    return {
      ...workspace,
      layers: updatedLayers,
      activeLayerId: newLayer.id,
      updatedAt: nowIso()
    }
  }

  static switchLayer(workspace: Workspace, layerId: string): Workspace {
    const target: Layer | undefined = workspace.layers.find((l: Layer) => l.id === layerId)
    if (!target) {
      return workspace
    }
    return { ...workspace, activeLayerId: layerId, updatedAt: nowIso() }
  }

  static renameActiveLayer(workspace: Workspace, name: string): Workspace {
    const trimmedName: string = name.trim()
    if (trimmedName.length === 0) {
      return workspace
    }

    const updatedLayers: Layer[] = workspace.layers.map((l: Layer) => {
      if (l.id === workspace.activeLayerId) {
        return { ...l, name: trimmedName, updatedAt: nowIso() } as Layer
      }
      return l
    })
    return { ...workspace, layers: updatedLayers, updatedAt: nowIso() }
  }

  static copyActiveLayer(workspace: Workspace): Workspace {
    const source: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!source) {
      return workspace
    }

    const nodeIdMap: Map<string, string> = new Map<string, string>()
    const now: string = nowIso()

    const newNodes: WordNode[] = source.nodes.map((n: WordNode) => {
      const newId: string = generateId('node')
      nodeIdMap.set(n.id, newId)
      return {
        ...n,
        id: newId,
        createdAt: now,
        updatedAt: now
      } as WordNode
    })

    const newEdges: WordEdge[] = source.edges.map((e: WordEdge) => {
      const newSource: string = nodeIdMap.get(e.source) ?? e.source
      const newTarget: string = nodeIdMap.get(e.target) ?? e.target
      return {
        ...e,
        id: generateId('edge'),
        source: newSource,
        target: newTarget,
        createdAt: now,
        updatedAt: now
      } as WordEdge
    })

    const newLayer: Layer = {
      id: generateId('layer'),
      name: `${source.name} 副本`,
      nodes: newNodes,
      edges: newEdges,
      viewport: { ...source.viewport },
      createdAt: now,
      updatedAt: now
    }

    const updatedLayers: Layer[] = [...workspace.layers, newLayer]
    return {
      ...workspace,
      layers: updatedLayers,
      activeLayerId: newLayer.id,
      updatedAt: nowIso()
    }
  }

  static searchCurrentLayer(workspace: Workspace, keyword: string): SearchResult[] {
    const layer: Layer | undefined = GraphService.getActiveLayer(workspace)
    if (!layer || keyword.trim().length === 0) {
      return []
    }

    const lowerKeyword: string = keyword.trim().toLowerCase()
    const results: SearchResult[] = []

    for (const node of layer.nodes) {
      const lowerLabel: string = node.label.toLowerCase()
      let score: number = 0

      if (lowerLabel === lowerKeyword) {
        score = 100
      } else if (lowerLabel.startsWith(lowerKeyword)) {
        score = 80
      } else if (lowerLabel.includes(lowerKeyword)) {
        score = 60
      }

      if (score > 0) {
        results.push({
          nodeId: node.id,
          label: node.label,
          layerId: layer.id,
          score: score
        })
      }
    }

    results.sort((a: SearchResult, b: SearchResult) => b.score - a.score)
    return results
  }

  static updateActiveViewport(workspace: Workspace, x: number, y: number, zoom: number): Workspace {
    const updatedLayers: Layer[] = workspace.layers.map((l: Layer) => {
      if (l.id === workspace.activeLayerId) {
        return { ...l, viewport: { x: x, y: y, zoom: zoom } } as Layer
      }
      return l
    })
    return { ...workspace, layers: updatedLayers }
  }
}
