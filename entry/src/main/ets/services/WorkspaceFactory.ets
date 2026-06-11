import { APP_NAME, DEFAULT_LAYER_NAME, WORKSPACE_VERSION } from '../constants/AppConstants'
import { Layer, WordEdge, WordNetSettings, WordNode, Workspace } from '../models/GraphModels'
import { generateId } from '../utils/IdUtil'
import { nowIso } from '../utils/TimeUtil'
import { makeEdgeKey } from '../utils/GeometryUtil'

export function createDefaultSettings(): WordNetSettings {
  return {
    autoSave: true,
    showGrid: false,
    defaultZoom: 1,
    confirmBeforeDelete: true,
    confirmBeforeClear: true
  }
}

export function createLayer(name: string = DEFAULT_LAYER_NAME): Layer {
  const now: string = nowIso()
  return {
    id: generateId('layer'),
    name: name,
    nodes: [],
    edges: [],
    viewport: { x: 0, y: 0, zoom: 1 },
    createdAt: now,
    updatedAt: now
  }
}

export function createDefaultWorkspace(): Workspace {
  const now: string = nowIso()
  const layer: Layer = createLayer(DEFAULT_LAYER_NAME)
  return {
    version: WORKSPACE_VERSION,
    appName: APP_NAME,
    activeLayerId: layer.id,
    layers: [layer],
    settings: createDefaultSettings(),
    createdAt: now,
    updatedAt: now
  }
}

export function createNode(label: string, x: number, y: number): WordNode {
  const now: string = nowIso()
  return {
    id: generateId('node'),
    label: label,
    x: x,
    y: y,
    note: '',
    style: {
      color: '',
      size: 'normal'
    },
    createdAt: now,
    updatedAt: now
  }
}

export function createEdge(source: string, target: string): WordEdge {
  const now: string = nowIso()
  return {
    id: generateId('edge'),
    source: source,
    target: target,
    relationType: 'related',
    label: '',
    createdAt: now,
    updatedAt: now
  }
}

export function ensureWorkspace(input: Workspace | undefined | null): Workspace {
  if (!input || !input.layers || input.layers.length === 0) {
    return createDefaultWorkspace()
  }

  const defaultSettings: WordNetSettings = createDefaultSettings()
  const settings: WordNetSettings = {
    autoSave: input.settings?.autoSave ?? defaultSettings.autoSave,
    showGrid: input.settings?.showGrid ?? defaultSettings.showGrid,
    defaultZoom: input.settings?.defaultZoom ?? defaultSettings.defaultZoom,
    confirmBeforeDelete: input.settings?.confirmBeforeDelete ?? defaultSettings.confirmBeforeDelete,
    confirmBeforeClear: input.settings?.confirmBeforeClear ?? defaultSettings.confirmBeforeClear
  }

  const layers: Layer[] = input.layers.map((layer: Layer) => {
    const nodeIds: Set<string> = new Set<string>()
    const nodes: WordNode[] = layer.nodes.map((node: WordNode) => {
      nodeIds.add(node.id)
      return {
        id: node.id,
        label: node.label ?? '',
        x: typeof node.x === 'number' ? node.x : 0,
        y: typeof node.y === 'number' ? node.y : 0,
        note: node.note ?? '',
        style: node.style ?? { color: '', size: 'normal' },
        createdAt: node.createdAt ?? nowIso(),
        updatedAt: node.updatedAt ?? nowIso()
      } as WordNode
    })

    const edgeKeys: Set<string> = new Set<string>()
    const edges: WordEdge[] = []
    for (const edge of layer.edges) {
      if (!edge.source || !edge.target) {
        continue
      }
      if (!nodeIds.has(edge.source) || !nodeIds.has(edge.target)) {
        continue
      }
      if (edge.source === edge.target) {
        continue
      }
      const key: string = makeEdgeKey(edge.source, edge.target)
      if (edgeKeys.has(key)) {
        continue
      }
      edgeKeys.add(key)
      edges.push({
        id: edge.id ?? generateId('edge'),
        source: edge.source,
        target: edge.target,
        relationType: edge.relationType ?? 'related',
        label: edge.label ?? '',
        createdAt: edge.createdAt ?? nowIso(),
        updatedAt: edge.updatedAt ?? nowIso()
      } as WordEdge)
    }

    const viewport = layer.viewport ?? { x: 0, y: 0, zoom: 1 }

    return {
      id: layer.id,
      name: layer.name ?? '未命名图层',
      nodes: nodes,
      edges: edges,
      viewport: viewport,
      createdAt: layer.createdAt ?? nowIso(),
      updatedAt: layer.updatedAt ?? nowIso()
    } as Layer
  })

  let activeLayerId: string = input.activeLayerId ?? ''
  if (!layers.find((l: Layer) => l.id === activeLayerId)) {
    activeLayerId = layers[0].id
  }

  return {
    version: input.version ?? WORKSPACE_VERSION,
    appName: input.appName ?? APP_NAME,
    activeLayerId: activeLayerId,
    layers: layers,
    settings: settings,
    createdAt: input.createdAt ?? nowIso(),
    updatedAt: input.updatedAt ?? nowIso()
  } as Workspace
}
