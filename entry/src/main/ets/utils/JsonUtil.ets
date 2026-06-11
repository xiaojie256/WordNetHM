export interface SafeJsonResult<T> {
  ok: boolean
  data?: T
  error?: string
}

export function safeJsonParse<T>(text: string): SafeJsonResult<T> {
  try {
    const data: T = JSON.parse(text) as T
    return { ok: true, data: data }
  } catch (err) {
    return { ok: false, error: `${err}` }
  }
}

export function prettyJson(data: Object): string {
  try {
    return JSON.stringify(data, null, 2)
  } catch (err) {
    return ''
  }
}
