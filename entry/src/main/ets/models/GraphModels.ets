export type RelationType = 'related'

export type SaveStatus = 'idle' | 'saving' | 'saved' | 'failed'

export type JsonDialogMode = 'import' | 'export'

export interface Viewport {
  x: number
  y: number
  zoom: number
}

export interface NodeStyle {
  color: string
  size: 'small' | 'normal' | 'large'
}

export interface WordNode {
  id: string
  label: string
  x: number
  y: number
  note: string
  style: NodeStyle
  createdAt: string
  updatedAt: string
}

export interface WordEdge {
  id: string
  source: string
  target: string
  relationType: RelationType
  label: string
  createdAt: string
  updatedAt: string
}

export interface Layer {
  id: string
  name: string
  nodes: WordNode[]
  edges: WordEdge[]
  viewport: Viewport
  createdAt: string
  updatedAt: string
}

export interface WordNetSettings {
  autoSave: boolean
  showGrid: boolean
  defaultZoom: number
  confirmBeforeDelete: boolean
  confirmBeforeClear: boolean
}

export interface Workspace {
  version: string
  appName: string
  activeLayerId: string
  layers: Layer[]
  settings: WordNetSettings
  createdAt: string
  updatedAt: string
}

export interface SearchResult {
  nodeId: string
  label: string
  layerId: string
  score: number
}

export interface Rect {
  left: number
  top: number
  right: number
  bottom: number
}

export interface Point {
  x: number
  y: number
}
