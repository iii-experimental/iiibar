import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { getTargetEngine } from './engine-client.js'
import { wsUrl } from './defaults.js'
import type {
  EngineProfile,
  HealthStatus,
  RuntimeEndpoint,
  RuntimeResources,
  RuntimeSummary,
  RuntimeWorker,
  WorkerMetrics,
} from './types.js'

const execFileAsync = promisify(execFile)

type RuntimeInputs = {
  workersRaw?: unknown
  functionsRaw?: unknown
  triggersRaw?: unknown
  health?: HealthStatus
  message?: string
  reachable?: boolean
}

export async function runtimeSummary(profile: EngineProfile): Promise<RuntimeSummary> {
  const target = getTargetEngine(profile)
  try {
    const [workersRaw, functionsRaw, triggersRaw, health] = await Promise.all([
      target.trigger<Record<string, never>, unknown>({
        function_id: 'engine::workers::list',
        payload: {},
        timeoutMs: 3000,
      }),
      target.trigger<{ include_internal: boolean }, unknown>({
        function_id: 'engine::functions::list',
        payload: { include_internal: true },
        timeoutMs: 3000,
      }),
      target.trigger<{ include_internal: boolean }, unknown>({
        function_id: 'engine::triggers::list',
        payload: { include_internal: true },
        timeoutMs: 3000,
      }),
      target.trigger<Record<string, never>, HealthStatus>({
        function_id: 'engine::health::check',
        payload: {},
        timeoutMs: 3000,
      }),
    ])

    const summary = buildRuntimeSummary(profile, {
      workersRaw,
      functionsRaw,
      triggersRaw,
      health,
      reachable: true,
    })
    return enrichLocalProcessMetrics(profile, summary)
  } catch (error) {
    return buildRuntimeSummary(profile, {
      reachable: false,
      message: error instanceof Error ? error.message : String(error),
    })
  }
}

export function buildRuntimeSummary(profile: EngineProfile, inputs: RuntimeInputs): RuntimeSummary {
  const now = Date.now()
  const workers = extractArray(inputs.workersRaw, 'workers')
    .map((worker) => normalizeWorker(worker, now))
    .filter((worker): worker is RuntimeWorker => worker !== null)
  const resources = summarizeResources(workers)
  const processIds = new Set(workers.map((worker) => worker.pid).filter((pid): pid is number => typeof pid === 'number'))
  const activeInvocations = workers.reduce((total, worker) => total + (worker.activeInvocations || 0), 0)
  const externalWorkerCount = workers.filter((worker) => !worker.internal).length
  const internalWorkerCount = workers.length - externalWorkerCount
  const status = inputs.reachable === false ? 'unreachable' : normalizeHealthStatus(inputs.health?.status)

  return {
    profile,
    reachable: inputs.reachable !== false,
    status,
    workerCount: workers.length,
    externalWorkerCount,
    internalWorkerCount,
    processCount: processIds.size + workers.filter((worker) => worker.pid === undefined).length,
    functionCount: countFunctions(inputs.functionsRaw),
    triggerCount: extractArray(inputs.triggersRaw, 'triggers').length,
    activeInvocations,
    longestUptimeSeconds: longestUptime(workers),
    endpoints: endpointsFor(profile),
    workers,
    runtimes: groupCount(workers.map((worker) => worker.runtime || 'unknown')),
    locations: groupLocations(workers, profile),
    resources,
    checkedAt: new Date(now).toISOString(),
    message: inputs.message,
  }
}

function normalizeWorker(input: unknown, now: number): RuntimeWorker | null {
  if (!input || typeof input !== 'object') return null
  const record = input as Record<string, unknown>
  const metrics = normalizeMetrics(record.latest_metrics)
  const connectedAtMs = numberValue(record.connected_at_ms)
  const metricUptime = numberValue(metrics?.uptime_seconds)
  const uptimeSeconds = metricUptime ?? (connectedAtMs ? Math.max(0, Math.round((now - connectedAtMs) / 1000)) : undefined)
  const functions = Array.isArray(record.functions) ? record.functions.length : undefined

  return {
    id: stringValue(record.id ?? record.worker_id) || 'unknown',
    name: stringValue(record.name) || stringValue(record.id ?? record.worker_id) || 'unknown worker',
    status: stringValue(record.status) || 'unknown',
    runtime: stringValue(record.runtime ?? metrics?.runtime),
    version: stringValue(record.version),
    os: stringValue(record.os),
    pid: numberValue(record.pid),
    ipAddress: stringValue(record.ip_address),
    internal: booleanValue(record.internal),
    functionCount: numberValue(record.function_count) ?? functions ?? 0,
    activeInvocations: numberValue(record.active_invocations) ?? 0,
    connectedAtMs,
    uptimeSeconds,
    memoryRssBytes: numberValue(metrics?.memory_rss),
    memoryHeapUsedBytes: numberValue(metrics?.memory_heap_used),
    cpuPercent: numberValue(metrics?.cpu_percent),
    eventLoopLagMs: numberValue(metrics?.event_loop_lag_ms),
  }
}

function endpointsFor(profile: EngineProfile): RuntimeEndpoint[] {
  return [
    { label: 'engine ws', url: wsUrl(profile), available: true },
    { label: 'rest', url: `http://${profile.host}:${profile.httpPort}`, available: true },
    { label: 'stream', url: `ws://${profile.host}:${profile.streamPort}`, available: true },
    { label: 'console', url: `http://${profile.host}:3113` },
  ]
}

function summarizeResources(workers: RuntimeWorker[]): RuntimeResources {
  const withMetrics = workers.filter(
    (worker) =>
      worker.cpuPercent !== undefined ||
      worker.memoryRssBytes !== undefined ||
      worker.memoryHeapUsedBytes !== undefined ||
      worker.eventLoopLagMs !== undefined,
  )
  const sum = (values: Array<number | undefined>) =>
    values.reduce<number>((total, value) => total + (typeof value === 'number' ? value : 0), 0)

  return {
    metricsAvailable: withMetrics.length > 0,
    workersWithMetrics: withMetrics.length,
    cpuPercent: withMetrics.some((worker) => worker.cpuPercent !== undefined) ? sum(withMetrics.map((worker) => worker.cpuPercent)) : undefined,
    memoryRssBytes: withMetrics.some((worker) => worker.memoryRssBytes !== undefined)
      ? sum(withMetrics.map((worker) => worker.memoryRssBytes))
      : undefined,
    memoryHeapUsedBytes: withMetrics.some((worker) => worker.memoryHeapUsedBytes !== undefined)
      ? sum(withMetrics.map((worker) => worker.memoryHeapUsedBytes))
      : undefined,
    eventLoopLagMs: withMetrics.some((worker) => worker.eventLoopLagMs !== undefined)
      ? Math.max(...withMetrics.map((worker) => worker.eventLoopLagMs ?? 0))
      : undefined,
  }
}

function groupLocations(workers: RuntimeWorker[], profile: EngineProfile): Record<string, number> {
  const locations = workers.map((worker) => worker.ipAddress || profile.host || 'unknown')
  return groupCount(locations)
}

function groupCount(values: string[]): Record<string, number> {
  return values.reduce<Record<string, number>>((acc, value) => {
    acc[value] = (acc[value] || 0) + 1
    return acc
  }, {})
}

function longestUptime(workers: RuntimeWorker[]): number | undefined {
  const values = workers.map((worker) => worker.uptimeSeconds).filter((value): value is number => typeof value === 'number')
  return values.length > 0 ? Math.max(...values) : undefined
}

async function enrichLocalProcessMetrics(profile: EngineProfile, summary: RuntimeSummary): Promise<RuntimeSummary> {
  if (profile.kind !== 'local' || !isLocalHost(profile.host)) return summary
  const pids = [...new Set(summary.workers.map((worker) => worker.pid).filter((pid): pid is number => typeof pid === 'number'))]
  if (pids.length === 0) return summary

  try {
    const { stdout } = await execFileAsync('/bin/ps', ['-o', 'pid=,pcpu=,rss=', '-p', pids.join(',')], {
      timeout: 1500,
      maxBuffer: 64 * 1024,
    })
    const processMetrics = parseProcessMetrics(stdout)
    if (processMetrics.size === 0) return summary
    const workers = summary.workers.map((worker) => {
      const metrics = worker.pid === undefined ? undefined : processMetrics.get(worker.pid)
      if (!metrics) return worker
      return {
        ...worker,
        cpuPercent: metrics.cpuPercent,
        memoryRssBytes: metrics.memoryRssBytes,
      }
    })
    return {
      ...summary,
      workers,
      resources: summarizeResources(workers),
    }
  } catch {
    return summary
  }
}

function parseProcessMetrics(stdout: string): Map<number, { cpuPercent: number; memoryRssBytes: number }> {
  const metrics = new Map<number, { cpuPercent: number; memoryRssBytes: number }>()
  for (const line of stdout.split('\n')) {
    const parts = line.trim().split(/\s+/)
    if (parts.length < 3) continue
    const pid = Number(parts[0])
    const cpuPercent = Number(parts[1])
    const rssKb = Number(parts[2])
    if (!Number.isFinite(pid) || !Number.isFinite(cpuPercent) || !Number.isFinite(rssKb)) continue
    metrics.set(pid, { cpuPercent, memoryRssBytes: rssKb * 1024 })
  }
  return metrics
}

function isLocalHost(host: string): boolean {
  return host === '127.0.0.1' || host === 'localhost' || host === '::1'
}

function countFunctions(input: unknown): number {
  const functions = extractArray(input, 'functions')
  if (functions.length > 0) return functions.length
  return extractArray(input, 'services').reduce<number>((total, service) => {
    if (!service || typeof service !== 'object') return total
    return total + extractArray(service, 'functions').length
  }, 0)
}

function extractArray(input: unknown, key: string): unknown[] {
  const root = unwrapBody(input)
  if (Array.isArray(root)) return root
  if (!root || typeof root !== 'object') return []
  const value = (root as Record<string, unknown>)[key]
  return Array.isArray(value) ? value : []
}

function unwrapBody(input: unknown): unknown {
  if (!input || typeof input !== 'object') return input
  const body = (input as Record<string, unknown>).body
  return body && typeof body === 'object' ? body : input
}

function normalizeMetrics(input: unknown): Partial<WorkerMetrics> | undefined {
  return input && typeof input === 'object' ? (input as Partial<WorkerMetrics>) : undefined
}

function normalizeHealthStatus(status?: string): RuntimeSummary['status'] {
  if (status === 'healthy') return 'healthy'
  if (status === 'degraded') return 'degraded'
  if (status === 'running') return 'healthy'
  return 'unknown'
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function numberValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function booleanValue(value: unknown): boolean {
  return typeof value === 'boolean' ? value : false
}
