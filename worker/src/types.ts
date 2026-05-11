export type EngineKind = 'local' | 'remote'
export type EngineTransport = 'direct' | 'bridge'

export type EngineProfile = {
  id: string
  name: string
  kind: EngineKind
  transport?: EngineTransport
  host: string
  httpPort: number
  bridgePort: number
  streamPort: number
  bridgeInvokeFunctionId?: string
  binaryPath?: string
  configPath?: string
  workingDirectory?: string
  env?: Record<string, string>
  autoStart?: boolean
  pollingIntervalSeconds?: number
}

export type ProfileListResult = {
  profiles: EngineProfile[]
  stateAvailable: boolean
  warning?: string
}

export type HealthComponent = {
  status: string
  details?: Record<string, unknown>
}

export type HealthStatus = {
  status: string
  timestamp?: number
  version?: string
  components?: Record<string, HealthComponent>
}

export type WorkerMetrics = {
  memory_heap_used?: number
  memory_heap_total?: number
  memory_rss?: number
  memory_external?: number
  cpu_user_micros?: number
  cpu_system_micros?: number
  cpu_percent?: number
  event_loop_lag_ms?: number
  uptime_seconds?: number
  timestamp_ms: number
  runtime: string
}

export type WorkerInfo = {
  worker_id?: string
  id?: string
  name?: string
  runtime?: string
  version?: string
  latest_metrics?: WorkerMetrics | null
  [key: string]: unknown
}

export type EngineStatus = {
  profile: EngineProfile
  state: 'healthy' | 'degraded' | 'unreachable' | 'unknown'
  reachable: boolean
  health?: HealthStatus
  workers: number
  functions: number
  triggers: number
  components: Record<string, string>
  checkedAt: string
  message?: string
}

export type RuntimeEndpoint = {
  label: string
  url: string
  available?: boolean
}

export type RuntimeWorker = {
  id: string
  name: string
  status: string
  runtime?: string
  version?: string
  os?: string
  pid?: number
  ipAddress?: string
  internal: boolean
  functionCount: number
  activeInvocations: number
  connectedAtMs?: number
  uptimeSeconds?: number
  memoryRssBytes?: number
  memoryHeapUsedBytes?: number
  cpuPercent?: number
  eventLoopLagMs?: number
}

export type RuntimeResources = {
  metricsAvailable: boolean
  workersWithMetrics: number
  cpuPercent?: number
  memoryRssBytes?: number
  memoryHeapUsedBytes?: number
  eventLoopLagMs?: number
}

export type RuntimeSummary = {
  profile: EngineProfile
  reachable: boolean
  status: 'healthy' | 'degraded' | 'unreachable' | 'unknown'
  workerCount: number
  externalWorkerCount: number
  internalWorkerCount: number
  processCount: number
  functionCount: number
  triggerCount: number
  activeInvocations: number
  longestUptimeSeconds?: number
  endpoints: RuntimeEndpoint[]
  workers: RuntimeWorker[]
  runtimes: Record<string, number>
  locations: Record<string, number>
  resources: RuntimeResources
  checkedAt: string
  message?: string
}

export type InvocationMetrics = {
  total: number
  success: number
  error: number
  deferred: number
  by_function: Record<string, number>
}

export type WorkerPoolMetrics = {
  spawns: number
  deaths: number
  active: number
}

export type PerformanceMetrics = {
  avg_duration_ms: number
  p50_duration_ms: number
  p95_duration_ms: number
  p99_duration_ms: number
  min_duration_ms: number
  max_duration_ms: number
}

export type MetricsResponse = {
  engine_metrics?: {
    invocations?: Partial<InvocationMetrics>
    workers?: Partial<WorkerPoolMetrics>
    performance?: Partial<PerformanceMetrics>
  }
  sdk_metrics?: unknown[]
  aggregated_metrics?: unknown[]
  timestamp?: number
}

export type OtelLog = {
  timestamp_unix_nano?: number
  severity_number?: number
  severity_text?: string
  body?: string
  service_name?: string
  trace_id?: string | null
  span_id?: string | null
  attributes?: Record<string, unknown>
  resource?: Record<string, unknown>
}

export type LogsResponse = {
  logs?: OtelLog[]
  total?: number
  timestamp?: number
}

export type StoredSpan = {
  trace_id: string
  span_id: string
  parent_span_id?: string
  name: string
  start_time_unix_nano?: number
  end_time_unix_nano?: number
  status?: string
  service_name?: string
  attributes?: Array<[string, unknown]>
}

export type TracesResponse = {
  spans?: StoredSpan[]
  total?: number
  offset?: number
  limit?: number
}

export type AlertsResponse = {
  alerts?: unknown[]
  alert_states?: unknown[]
  [key: string]: unknown
}

export type TelemetrySummary = {
  profile: EngineProfile
  available: boolean
  invocations: InvocationMetrics
  workers: WorkerPoolMetrics
  performance: PerformanceMetrics
  recentErrors: number
  recentWarnings: number
  errorTraces: number
  slowTraces: number
  alerts: number
  checkedAt: string
  warning?: string
}

export type ProcessState = {
  profileId: string
  running: boolean
  pid?: number
  startedAt?: string
  stoppedAt?: string
  message?: string
}

export type DiagnosticsResult = {
  text: string
  diagnostics: {
    status: EngineStatus
    telemetry: TelemetrySummary
    runtime: RuntimeSummary
    logs: LogsResponse
    traces: TracesResponse
  }
}
