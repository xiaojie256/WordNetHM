export function generateId(prefix: string): string {
  const randomPart: string = Math.random().toString(36).slice(2, 10)
  const timePart: string = Date.now().toString(36)
  return `${prefix}_${timePart}_${randomPart}`
}
