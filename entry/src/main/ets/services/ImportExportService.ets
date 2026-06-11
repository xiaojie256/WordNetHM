import { Workspace } from '../models/GraphModels'
import { nowIso } from '../utils/TimeUtil'
import { prettyJson, safeJsonParse } from '../utils/JsonUtil'
import { validateImportedWorkspace } from './WorkspaceValidator'

export class ImportExportService {
  static exportToJson(workspace: Workspace): string {
    const exportData: Object = {
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
    const result = safeJsonParse<Object>(jsonText)
    if (!result.ok || !result.data) {
      throw new Error(`JSON 解析失败: ${result.error}`)
    }
    const validation = validateImportedWorkspace(result.data)
    if (!validation.ok || !validation.workspace) {
      throw new Error(`数据校验失败: ${validation.error}`)
    }
    return validation.workspace
  }

  static getDefaultExportFileName(): string {
    const dateStr: string = new Date().toISOString().slice(0, 10)
    return `wordnet_export_${dateStr}.json`
  }
}
