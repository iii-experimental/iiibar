import { describe, expect, it } from 'vitest'
import { defaultProfile } from '../src/defaults.js'
import { buildTelemetrySummary } from '../src/telemetry.js'

describe('telemetry summary', () => {
  it('aggregates metrics, logs, traces, and alerts', () => {
    const summary = buildTelemetrySummary({
      profile: defaultProfile,
      metrics: {
        engine_metrics: {
          invocations: { total: 10, success: 8, error: 2, deferred: 1, by_function: { a: 10 } },
          workers: { spawns: 3, deaths: 1, active: 2 },
          performance: { avg_duration_ms: 12, p95_duration_ms: 99 },
        },
      },
      logs: {
        logs: [
          { severity_text: 'WARN', body: 'warn' },
          { severity_text: 'ERROR', body: 'error' },
        ],
      },
      traces: {
        spans: [
          {
            trace_id: 't',
            span_id: 's',
            name: 'slow',
            status: 'error',
            start_time_unix_nano: 0,
            end_time_unix_nano: 2_000_000_000,
          },
        ],
      },
      alerts: {
        alerts: [{ name: 'high_error_rate' }],
      },
    })

    expect(summary.available).toBe(true)
    expect(summary.invocations.total).toBe(10)
    expect(summary.workers.active).toBe(2)
    expect(summary.performance.p95_duration_ms).toBe(99)
    expect(summary.recentWarnings).toBe(1)
    expect(summary.recentErrors).toBe(1)
    expect(summary.errorTraces).toBe(1)
    expect(summary.slowTraces).toBe(1)
    expect(summary.alerts).toBe(1)
  })

  it('marks unavailable telemetry with a warning', () => {
    const summary = buildTelemetrySummary({
      profile: defaultProfile,
      warning: 'engine::metrics::list not found',
    })
    expect(summary.available).toBe(false)
    expect(summary.warning).toContain('metrics')
  })
})
