import type {
  AlertsResponse,
  InvocationMetrics,
  LogsResponse,
  MetricsResponse,
  PerformanceMetrics,
  TelemetrySummary,
  TracesResponse,
  WorkerPoolMetrics,
  EngineProfile,
} from './types.js'

export function buildTelemetrySummary(input: {
  profile: EngineProfile
  metrics?: MetricsResponse
  logs?: LogsResponse
  traces?: TracesResponse
  alerts?: AlertsResponse
  warning?: string
}): TelemetrySummary {
  const invocations = normalizeInvocations(input.metrics?.engine_metrics?.invocations)
  const workers = normalizeWorkers(input.metrics?.engine_metrics?.workers)
  const performance = normalizePerformance(input.metrics?.engine_metrics?.performance)
  const logs = input.logs?.logs || []
  const spans = input.traces?.spans || []
  const alertCount = countAlerts(input.alerts)

  return {
    profile: input.profile,
    available: Boolean(input.metrics || input.logs || input.traces),
    invocations,
    workers,
    performance,
    recentErrors: logs.filter((log) => isErrorSeverity(log.severity_text, log.severity_number)).length,
    recentWarnings: logs.filter((log) => isWarnSeverity(log.severity_text, log.severity_number)).length,
    errorTraces: spans.filter((span) => `${span.status || ''}`.toLowerCase() === 'error').length,
    slowTraces: spans.filter((span) => spanDurationMs(span) >= 1000).length,
    alerts: alertCount,
    checkedAt: new Date().toISOString(),
    warning: input.warning,
  }
}

function normalizeInvocations(input?: Partial<InvocationMetrics>): InvocationMetrics {
  return {
    total: Number(input?.total || 0),
    success: Number(input?.success || 0),
    error: Number(input?.error || 0),
    deferred: Number(input?.deferred || 0),
    by_function: input?.by_function || {},
  }
}

function normalizeWorkers(input?: Partial<WorkerPoolMetrics>): WorkerPoolMetrics {
  return {
    spawns: Number(input?.spawns || 0),
    deaths: Number(input?.deaths || 0),
    active: Number(input?.active || 0),
  }
}

function normalizePerformance(input?: Partial<PerformanceMetrics>): PerformanceMetrics {
  return {
    avg_duration_ms: Number(input?.avg_duration_ms || 0),
    p50_duration_ms: Number(input?.p50_duration_ms || 0),
    p95_duration_ms: Number(input?.p95_duration_ms || 0),
    p99_duration_ms: Number(input?.p99_duration_ms || 0),
    min_duration_ms: Number(input?.min_duration_ms || 0),
    max_duration_ms: Number(input?.max_duration_ms || 0),
  }
}

function isErrorSeverity(text?: string, number?: number): boolean {
  return `${text || ''}`.toUpperCase() === 'ERROR' || Number(number || 0) >= 17
}

function isWarnSeverity(text?: string, number?: number): boolean {
  const normalized = `${text || ''}`.toUpperCase()
  return normalized === 'WARN' || normalized === 'WARNING' || Number(number || 0) >= 13
}

function spanDurationMs(span: { start_time_unix_nano?: number; end_time_unix_nano?: number }): number {
  if (span.start_time_unix_nano === undefined || span.end_time_unix_nano === undefined) return 0
  const start = Number(span.start_time_unix_nano)
  const end = Number(span.end_time_unix_nano)
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return 0
  return (end - start) / 1_000_000
}

function countAlerts(alerts?: AlertsResponse): number {
  const direct = Array.isArray(alerts?.alerts) ? alerts.alerts.length : 0
  const states = Array.isArray(alerts?.alert_states) ? alerts.alert_states.length : 0
  return direct + states
}
