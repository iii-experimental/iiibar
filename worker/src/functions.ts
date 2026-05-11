import { triggerEngine, type IiiClient } from './engine-client.js'
import { resolveProfile, resolveStoredProfile, listProfiles, saveProfile } from './profile-store.js'
import { startEngine, stopEngine } from './process-controller.js'
import { runtimeSummary } from './runtime.js'
import { componentStatuses, countFunctions, countTriggers, countWorkers, deriveEngineState } from './status.js'
import { buildTelemetrySummary } from './telemetry.js'
import type {
  AlertsResponse,
  DiagnosticsResult,
  EngineProfile,
  EngineStatus,
  HealthStatus,
  OtelLog,
  LogsResponse,
  MetricsResponse,
  RuntimeSummary,
  StoredSpan,
  TelemetrySummary,
  TracesResponse,
} from './types.js'

export function registerIiiBarFunctions(control: IiiClient): void {
  control.registerService({
    id: 'iiibar',
    name: 'iiiBar',
    description: 'macOS menu bar control plane for iii engines',
  })

  control.registerFunction('iiibar::profiles::list', async () => listProfiles(control), {
    description: 'List iiiBar engine profiles from iii state.',
  })
  control.registerFunction('iiibar::profiles::save', async (input: Partial<EngineProfile>) => saveProfile(control, input), {
    description: 'Save an iiiBar engine profile through iii state.',
  })
  control.registerFunction('iiibar::engines::status', async (input: { profileId?: string; profile?: Partial<EngineProfile> }) => {
    const profile = await resolveProfile(control, input || {})
    return engineStatus(profile)
  })
  control.registerFunction('iiibar::engines::start', async (input: { profileId?: string; profile?: Partial<EngineProfile> }) => {
    const profile = await resolveStoredProfile(control, input || {})
    return startEngine(profile)
  })
  control.registerFunction('iiibar::engines::stop', async (input: { profileId?: string; profile?: Partial<EngineProfile> }) => {
    const profile = await resolveStoredProfile(control, input || {})
    return stopEngine(profile)
  })
  control.registerFunction('iiibar::telemetry::summary', async (input: { profileId?: string; profile?: Partial<EngineProfile> }) => {
    const profile = await resolveProfile(control, input || {})
    return telemetrySummary(profile)
  })
  control.registerFunction('iiibar::runtime::summary', async (input: { profileId?: string; profile?: Partial<EngineProfile> }) => {
    const profile = await resolveProfile(control, input || {})
    return runtimeSummary(profile)
  })
  control.registerFunction('iiibar::logs::recent', async (input: { profileId?: string; profile?: Partial<EngineProfile>; limit?: number }) => {
    const profile = await resolveProfile(control, input || {})
    return recentLogs(profile, input?.limit)
  })
  control.registerFunction('iiibar::traces::recent', async (input: { profileId?: string; profile?: Partial<EngineProfile>; limit?: number }) => {
    const profile = await resolveProfile(control, input || {})
    return recentTraces(profile, input?.limit)
  })
  control.registerFunction('iiibar::diagnostics::copy', async (input: { profileId?: string; profile?: Partial<EngineProfile> }) => {
    const profile = await resolveProfile(control, input || {})
    return diagnostics(profile)
  })
}

export async function engineStatus(profile: EngineProfile): Promise<EngineStatus> {
  try {
    const [health, workers, functions, triggers] = await Promise.all([
      triggerEngine<Record<string, never>, HealthStatus>(profile, {
        function_id: 'engine::health::check',
        payload: {},
        timeoutMs: 3000,
      }),
      triggerEngine<Record<string, never>, unknown>(profile, {
        function_id: 'engine::workers::list',
        payload: {},
        timeoutMs: 3000,
      }),
      triggerEngine<{ include_internal: boolean }, unknown>(profile, {
        function_id: 'engine::functions::list',
        payload: { include_internal: false },
        timeoutMs: 3000,
      }),
      triggerEngine<{ include_internal: boolean }, unknown>(profile, {
        function_id: 'engine::triggers::list',
        payload: { include_internal: false },
        timeoutMs: 3000,
      }),
    ])

    return {
      profile,
      state: deriveEngineState(health, true),
      reachable: true,
      health,
      workers: countWorkers(workers),
      functions: countFunctions(functions),
      triggers: countTriggers(triggers),
      components: componentStatuses(health),
      checkedAt: new Date().toISOString(),
    }
  } catch (error) {
    return {
      profile,
      state: 'unreachable',
      reachable: false,
      workers: 0,
      functions: 0,
      triggers: 0,
      components: {},
      checkedAt: new Date().toISOString(),
      message: error instanceof Error ? error.message : String(error),
    }
  }
}

export async function telemetrySummary(profile: EngineProfile): Promise<TelemetrySummary> {
  try {
    const [metrics, logs, traces, alerts] = await Promise.all([
      triggerEngine<Record<string, never>, MetricsResponse>(profile, {
        function_id: 'engine::metrics::list',
        payload: {},
        timeoutMs: 3000,
      }),
      recentLogs(profile, 100),
      recentTraces(profile, 100),
      triggerEngine<Record<string, never>, AlertsResponse>(profile, {
        function_id: 'engine::alerts::list',
        payload: {},
        timeoutMs: 3000,
      }),
    ])

    return buildTelemetrySummary({ profile, metrics, logs, traces, alerts })
  } catch (error) {
    return buildTelemetrySummary({
      profile,
      warning: error instanceof Error ? error.message : String(error),
    })
  }
}

export async function recentLogs(profile: EngineProfile, limit = 50): Promise<LogsResponse> {
  const normalizedLimit = normalizeLimit(limit)
  const response = await triggerEngine<{ offset: number; limit: number; severity_min?: number }, LogsResponse>(profile, {
    function_id: 'engine::logs::list',
    payload: {
      offset: 0,
      limit: Math.max(normalizedLimit * 4, 50),
      severity_min: 13,
    },
    timeoutMs: 3000,
  })
  return {
    ...response,
    logs: (response.logs || []).filter((log) => !isIiiBarInternalLog(log)).slice(0, normalizedLimit),
  }
}

export async function recentTraces(profile: EngineProfile, limit = 50): Promise<TracesResponse> {
  const normalizedLimit = normalizeLimit(limit)
  const response = await triggerEngine<{ offset: number; limit: number; sort_by: string; sort_order: string }, TracesResponse>(profile, {
    function_id: 'engine::traces::list',
    payload: {
      offset: 0,
      limit: Math.max(normalizedLimit * 4, 50),
      sort_by: 'start_time',
      sort_order: 'desc',
    },
    timeoutMs: 3000,
  })
  return {
    ...response,
    spans: (response.spans || []).filter((span) => !isIiiBarInternalSpan(span)).slice(0, normalizedLimit),
  }
}

export async function diagnostics(profile: EngineProfile): Promise<DiagnosticsResult> {
  const [status, telemetry, runtime, logs, traces] = await Promise.all([
    engineStatus(profile),
    telemetrySummary(profile),
    runtimeSummary(profile),
    recentLogs(profile, 20).catch(() => ({ logs: [], total: 0 })),
    recentTraces(profile, 20).catch(() => ({ spans: [], total: 0 })),
  ])
  const diagnostics = { status, telemetry, runtime, logs, traces }
  return {
    text: JSON.stringify(diagnostics, null, 2),
    diagnostics,
  }
}

function isIiiBarInternalLog(log: OtelLog): boolean {
  const attributes = log.attributes || {}
  const body = stripAnsi(`${log.body || ''}`).toLowerCase()
  const functionId = `${attributes.function_id || ''}`.toLowerCase()
  const functionName = `${attributes.function_name || ''}`.toLowerCase()
  const serviceName = `${attributes.service_name || ''}`.toLowerCase()

  return (
    functionId.startsWith('iiibar::') ||
    functionName.startsWith('iiibar::') ||
    serviceName === 'iiibar' ||
    body.includes('iiibar::') ||
    body.includes('iiibar-worker') ||
    body.includes('iiibar')
  )
}

function isIiiBarInternalSpan(span: StoredSpan): boolean {
  const fields = [
    span.name,
    span.service_name || '',
    ...(span.attributes || []).map(([key, value]) => `${key}:${String(value)}`),
  ]
    .join(' ')
    .toLowerCase()

  return fields.includes('iiibar::') || fields.includes('iiibar-worker') || fields.includes('service_name:iiibar')
}

function stripAnsi(value: string): string {
  return value.replace(/\u001b\[[0-9;]*m/g, '')
}

function normalizeLimit(value: unknown): number {
  const limit = Number(value)
  if (!Number.isFinite(limit)) return 50
  return Math.min(200, Math.max(1, Math.floor(limit)))
}
