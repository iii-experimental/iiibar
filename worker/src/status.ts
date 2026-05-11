import type { EngineStatus, HealthStatus, WorkerInfo } from './types.js'

export function deriveEngineState(health?: HealthStatus, reachable = true): EngineStatus['state'] {
  if (!reachable) return 'unreachable'
  if (!health) return 'unknown'
  if (health.status === 'healthy') return 'healthy'
  if (health.status === 'degraded') return 'degraded'
  if (health.status === 'running') return 'healthy'
  return 'degraded'
}

export function componentStatuses(health?: HealthStatus): Record<string, string> {
  if (!health?.components) return {}
  return Object.fromEntries(
    Object.entries(health.components).map(([name, component]) => [name, component?.status || 'unknown']),
  )
}

export function countWorkers(workersResponse: unknown): number {
  return extractArray(workersResponse, 'workers').length
}

export function countFunctions(functionsResponse: unknown): number {
  return extractArray(functionsResponse, 'functions').length
}

export function countTriggers(triggersResponse: unknown): number {
  return extractArray(triggersResponse, 'triggers').length
}

export function summarizeWorkerRuntimes(workers: WorkerInfo[]): Record<string, number> {
  return workers.reduce<Record<string, number>>((acc, worker) => {
    const runtime = worker.runtime || worker.latest_metrics?.runtime || 'unknown'
    acc[runtime] = (acc[runtime] || 0) + 1
    return acc
  }, {})
}

function extractArray(input: unknown, key: string): unknown[] {
  if (!input || typeof input !== 'object') return []
  const value = (input as Record<string, unknown>)[key]
  return Array.isArray(value) ? value : []
}
