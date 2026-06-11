import { preferences } from '@kit.ArkData'
import { Workspace } from '../models/GraphModels'
import { STORAGE_FILE_NAME, STORAGE_WORKSPACE_KEY } from '../constants/AppConstants'
import { common } from '@kit.AbilityKit'
import { safeJsonParse } from '../utils/JsonUtil'

let prefStore: preferences.Preferences | null = null

async function getPreferences(context: common.UIAbilityContext): Promise<preferences.Preferences> {
  if (prefStore !== null) {
    return prefStore
  }
  const store: preferences.Preferences = await preferences.getPreferences(context, STORAGE_FILE_NAME)
  prefStore = store
  return store
}

export class StorageService {
  static async loadWorkspace(context: common.UIAbilityContext): Promise<Workspace | undefined> {
    try {
      const store: preferences.Preferences = await getPreferences(context)
      const jsonStr: preferences.ValueType = await store.get(STORAGE_WORKSPACE_KEY, '')
      if (typeof jsonStr !== 'string' || jsonStr.length === 0) {
        return undefined
      }
      const result = safeJsonParse<Workspace>(jsonStr)
      if (result.ok && result.data) {
        return result.data
      }
      return undefined
    } catch (err) {
      console.error('[StorageService] loadWorkspace failed')
      return undefined
    }
  }

  static async saveWorkspace(context: common.UIAbilityContext, workspace: Workspace): Promise<void> {
    try {
      const store: preferences.Preferences = await getPreferences(context)
      const jsonStr: string = JSON.stringify(workspace)
      await store.put(STORAGE_WORKSPACE_KEY, jsonStr)
      await store.flush()
    } catch (err) {
      console.error('[StorageService] saveWorkspace failed')
      throw new Error('保存失败')
    }
  }

  static async clearWorkspace(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await getPreferences(context)
      await store.delete(STORAGE_WORKSPACE_KEY)
      await store.flush()
    } catch (err) {
      console.error('[StorageService] clearWorksp