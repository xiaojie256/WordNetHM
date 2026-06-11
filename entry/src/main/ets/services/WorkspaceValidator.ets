import { Workspace } from '../models/GraphModels'
import { ensureWorkspace } from './WorkspaceFactory'

export interface ValidationResult {
  ok: boolean
  workspace?: Workspace
  error?: string
}

function buildValidationFail(errorMsg: string): ValidationResult {
  const result: ValidationResult = {
    ok: false,
    error: errorMsg
  }
  return result
}

function buildValidationOk(ws: Workspace): ValidationResult {
  const result: ValidationResult = {
    ok: true,
    workspace: ws
  }
  return result
}

export function validateImportedWorkspace(raw: Object): ValidationResult {
  if (!raw || typeof raw !== 'object') {
    return buildValidationFail('导入数据不是有效对象')
  }

  const obj: Record<string, Object> = raw as Record<string, Object>
  const layers: Object | undefined = obj['layers']

  if (!Array.isArray(layers)) {
    return buildValidationFail('缺少 layers 数组')
  }

  const layerArr: Object[] = layers as Object[]
  for (let i: number = 0; i < layerArr.length; i++) {
    const layer: Record<string, Object> = layerArr[i] as Record<string, Object>
    if (!layer['id'] || !layer['name']) {
      return buildValidationFail('图层 ' + i + ' 缺少 id 或 name')
    }
    if (!Array.isArray(layer['nodes'])) {
      return buildValidationFail('图层 ' + i + ' 的 nodes 不是数组')
    }
    if (!Array.isArray(layer['edges'])) {
      return buildValidationFail('图层 ' + i + ' 的 edges 不是数组')
    }

    const nodesArr: Object[] = layer['nodes'] as Object[]
    for (let j: number = 0; j < nodesArr.length; j++) {
      const node: Record<string, Object> = nodesArr[j] as Record<string, Object>
      if (!node['id'] || !node['label']) {
        return buildValidationFail('图层 ' + i + ' 节点 ' + j + ' 缺少 id 或 label')
      }
      if (typeof node['x'] !== 'number' || typeof node['y'] !== 'number') {
        return buildValidationFail('