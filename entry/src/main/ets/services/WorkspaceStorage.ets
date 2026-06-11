import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { WorkspaceData } from '../models/GraphModels'
import { createDefaultWorkspace, normalizeWorkspace } from './WorkspaceFactory'

const STORAGE_FILE_NAME: string = 'wordnet_storage'
const WORKSPACE_KEY: string = 'workspace_json'

export class WorkspaceStorage {
  static async loadWorkspace(context: common.UIAbilityContext): Promise<WorkspaceData> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, STORAGE_FILE_NAME)
      const value: preferences.ValueType = await store.get(WORKSPACE_KEY, '')
      if (typeof value !== 'string') {
        return createDefaultWorkspace()
      }
      if (value.length === 0) {
        return createDefaultWorkspace()
      }
      const parsed: WorkspaceData = JSON.parse(value) as WorkspaceData
      return normalizeWorkspace(parsed)
    } catch (err) {
      return createDefaultWorkspace()
    }
  }

  static async saveWorkspace(context: common.UIAbilityContext, workspace: WorkspaceData): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, STORAGE_FILE_NAME)
      const jsonText: string = JSON.stringify(workspace)
      await store.put(WORKSPACE_KEY, jsonText)
      await store.flush()
    } catch (err) {
      // 保存失败不让应用崩溃
    }
  }
}
