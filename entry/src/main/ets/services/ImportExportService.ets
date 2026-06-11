import { Layer, WordNetSettings, Workspace } from '../models/GraphModels'
import { nowIso } from '../utils/TimeUtil'
import { prettyJson, safeJsonParse } from '../utils/JsonUtil'
import { validateImportedWorkspace } from './WorkspaceValidator'

interface ExportData {
  version: string
  appName: string
  exportedAt: string
  activeLayerId: string
  layers: Layer[]
  settings: WordNetSettings
  createdAt: string
  updatedAt: string
}

export class ImportExportService {
  static exportToJson(workspace: Workspace): string {
    const exportData: ExportData = {
      version: workspace.version,
      appName: workspace.appName,
      exportedAt: nowIso(),
      activeLayerId: workspace.activeLayerId,
      layers: workspace.layers,
      settings: workspace.settings,
      createdAt: workspace.createdAt,
      updatedAt: workspace.updatedAt
    }
    return prettyJson(exportData)
  }

  static importFromJson(jsonText: string): Workspace {
    const result = safeJsonParse<Workspace>(jsonText)
    if (!result.ok || !result.data) {
      throw new Error('JSON 解析失败: ' + (result.error ?? '未知错误'))
    }
    const validation = validateImportedWorkspace(result.data)
    if (!validation.ok || !validation.workspace) {
      throw new Error('数