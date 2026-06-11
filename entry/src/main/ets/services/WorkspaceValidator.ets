import { Workspace } from '../models/GraphModels'
import { ensureWorkspace } from './WorkspaceFactory'

export interface ValidationResult {
  ok: boolean
  workspace?: Workspace
  error?: string
}

export function validateImportedWorkspace(raw: Object): ValidationResult {
  if (!raw || typeof raw !== 'object') {
    return { ok: false, error: '导入数据不是有效对象' }
  }

  const obj = raw as Record<string, Object>
  const layers = obj['layers']

  if (!Array.isArray(layers)) {
    return { ok: false, error: '缺少 layers 数组' }
  }

  const layerArr = layers as Object[]
  for (let i = 0; i < layerArr.length; i++) {
    const layer = layerArr[i] as Record<string, Object>
    if (!layer['id'] || !layer['name']) {
      return { ok: false, error: `图层 ${i} 缺少 id 或 name` }
    }
    if (!Array.isArray(layer['nodes'])) {
      return { ok: false, error: `图层 ${i} 的 nodes 不是数组` }
    }
    if (!Array.isArray(layer['edges'])) {
      return { ok: false, error: `图层 ${i} 的 edges 不是数组` }
    }

    const nodesArr = layer['nodes'] as Object[]
    for (let j = 0; j < nodesArr.length; j++) {
      const node = nodesArr[j] as Record<string, Object>
      if (!node['id'] || !node['label']) {
        return { ok: false, error: `图层 ${i} 节点 ${j} 缺少 id 或 label` }
      }
      if (typeof node['x'] !== 'number' || typeof node['y'] !== 'number') {
        return { ok: false, error: `图层 ${i} 节点 ${j} 的坐标无效` }
      }
    }

    const edgesArr = layer['edges'] as Object[]
    for (let j = 0; j < edgesArr.length; j++) {
      const edge = edgesArr[j] as Record<string, Object>
      if (!edge['source'] || !edge['target']) {
        return { ok: false, error: `图层 ${i} 边 ${j} 缺少 source 或 target` }
      }
    }
  }

  const workspace = ensureWorkspace(raw as Workspace)
  return { ok: true, workspace: workspace }
}
