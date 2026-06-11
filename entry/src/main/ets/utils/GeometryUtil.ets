import { Point, Rect, Viewport, WordNode } from '../models/GraphModels'
import { NODE_HEIGHT, NODE_HORIZONTAL_PADDING, NODE_MIN_WIDTH } from '../constants/AppConstants'

export function getNodeWidth(label: string): number {
  const textWidth: number = Math.max(label.length * 10 + NODE_HORIZONTAL_PADDING * 2, NODE_MIN_WIDTH)
  return Math.min(textWidth, 220)
}

export function worldToScreen(point: Point, viewport: Viewport): Point {
  return {
    x: point.x * viewport.zoom + viewport.x,
    y: point.y * viewport.zoom + viewport.y
  }
}

export function screenToWorld(point: Point, viewport: Viewport): Point {
  return {
    x: (point.x - viewport.x) / viewport.zoom,
    y: (point.y - viewport.y) / viewport.zoom
  }
}

export function getNodeRect(node: WordNode): Rect {
  const width: number = getNodeWidth(node.label)
  return {
    left: node.x - width / 2,
    top: node.y - NODE_HEIGHT / 2,
    right: node.x + width / 2,
    bottom: node.y + NODE_HEIGHT / 2
  }
}

export function isPointInRect(point: Point, rect: Rect): boolean {
  return point.x >= rect.left && point.x <= rect.right &&
    point.y >= rect.top && point.y <= rect.bottom
}

export function normalizeRect(start: Point, end: Point): Rect {
  return {
    left: Math.min(start.x, end.x),
    top: Math.min(start.y, end.y),
    right: Math.max(start.x, end.x),
    bottom: Math.max(start.y, end.y)
  }
}

export function isNodeInRect(node: WordNode, rect: Rect): boolean {
  const nodeRect: Rect = getNodeRect(node)
  const center: Point = { x: node.x, y: node.y }
  return isPointInRect(center, rect) ||
    !(nodeRect.right < rect.left || nodeRect.left > rect.right ||
      nodeRect.bottom < rect.top || nodeRect.top > rect.bottom)
}

export function makeEdgeKey(source: string, target: string): string {
  return [source, target].sort().join('__')
}
