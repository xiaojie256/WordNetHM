import { promptAction } from '@kit.ArkUI'

export function showToast(message: string, duration: number = 2000): void {
  try {
    promptAction.showToast({
      message: message,
      duration: duration
    })
  } catch (err) {
    console.info(`[Toast] ${message}`)
  }
}
