export const APP_NAME: string = 'WordNet Pro'
export const WORKSPACE_VERSION: string = '1.0.0'
export const DEFAULT_LAYER_NAME: string = '默认图层'
export const STORAGE_FILE_NAME: string = 'wordnet_preferences'
export const STORAGE_WORKSPACE_KEY: string = 'workspace_json'
export const AUTO_SAVE_DELAY_MS: number = 800

export const NODE_MIN_WIDTH: number = 88
export const NODE_HEIGHT: number = 44
export const NODE_HORIZONTAL_PADDING: number = 16
export const NODE_RADIUS: number = 16

export const MIN_ZOOM: number = 0.35
export const MAX_ZOOM: number = 2.5
export const ZOOM_STEP: number = 0.15

export const LARGE_CONNECTION_CONFIRM_THRESHOLD: number = 45

export interface ColorScheme {
  pageBg: string
  panelBg: string
  panelBorder: string
  textPrimary: string
  textSecondary: string
  primary: string
  primaryLight: string
  danger: string
  warning: string
  nodeBg: string
  nodeBorder: string
  nodeSelectedBorder: string
  nodeHighlightedBorder: string
  edge: string
  edgeSelected: string
  selectionFill: string
  selectionStroke: string
}

export const COLORS: ColorScheme = {
  pageBg: '#F8FAFC',
  panelBg: '#FFFFFF',
  pan