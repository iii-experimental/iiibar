import { describe, expect, it } from 'vitest'
import { colorForStatus, iiiColors } from '../src/brand.js'
import { componentStatuses, deriveEngineState, summarizeWorkerRuntimes } from '../src/status.js'

describe('status helpers', () => {
  it('maps health to engine state', () => {
    expect(deriveEngineState({ status: 'healthy' }, true)).toBe('healthy')
    expect(deriveEngineState({ status: 'degraded' }, true)).toBe('degraded')
    expect(deriveEngineState(undefined, false)).toBe('unreachable')
  })

  it('extracts component statuses', () => {
    expect(
      componentStatuses({
        status: 'healthy',
        components: {
          otel: { status: 'healthy' },
          metrics: { status: 'degraded' },
        },
      }),
    ).toEqual({ otel: 'healthy', metrics: 'degraded' })
  })

  it('summarizes worker runtimes', () => {
    expect(
      summarizeWorkerRuntimes([
        { runtime: 'node' },
        { runtime: 'node' },
        { latest_metrics: { runtime: 'python', timestamp_ms: 1 } },
      ]),
    ).toEqual({ node: 2, python: 1 })
  })

  it('uses iii.dev semantic colors', () => {
    expect(colorForStatus('healthy')).toBe(iiiColors.success)
    expect(colorForStatus('degraded')).toBe(iiiColors.warn)
    expect(colorForStatus('unreachable')).toBe(iiiColors.alert)
    expect(colorForStatus('unknown')).toBe(iiiColors.medium)
  })
})
