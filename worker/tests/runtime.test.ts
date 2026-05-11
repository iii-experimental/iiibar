import { describe, expect, it } from 'vitest'
import { defaultProfile } from '../src/defaults.js'
import { buildRuntimeSummary } from '../src/runtime.js'

describe('runtime summary', () => {
  it('summarizes workers, resources, endpoints, and locations', () => {
    const summary = buildRuntimeSummary(defaultProfile, {
      reachable: true,
      health: { status: 'healthy' },
      workersRaw: {
        workers: [
          {
            id: 'one',
            name: 'worker-one',
            status: 'running',
            runtime: 'node',
            pid: 123,
            ip_address: '127.0.0.1',
            function_count: 7,
            active_invocations: 2,
            latest_metrics: {
              timestamp_ms: 1,
              runtime: 'node',
              memory_rss: 64 * 1024 * 1024,
              memory_heap_used: 24 * 1024 * 1024,
              cpu_percent: 12.5,
            },
          },
          {
            id: 'two',
            name: 'worker-two',
            status: 'running',
            runtime: 'rust',
            pid: 456,
            ip_address: '127.0.0.1',
            function_count: 3,
          },
          {
            id: 'three',
            name: 'worker-three',
            status: 'running',
            runtime: 'python',
            ip_address: '127.0.0.1',
            function_count: 1,
          },
        ],
      },
      functionsRaw: { functions: [{ id: 'a' }, { id: 'b' }] },
      triggersRaw: { triggers: [{ id: 't' }] },
    })

    expect(summary.status).toBe('healthy')
    expect(summary.workerCount).toBe(3)
    expect(summary.processCount).toBe(3)
    expect(summary.functionCount).toBe(2)
    expect(summary.triggerCount).toBe(1)
    expect(summary.activeInvocations).toBe(2)
    expect(summary.resources.metricsAvailable).toBe(true)
    expect(summary.resources.cpuPercent).toBe(12.5)
    expect(summary.resources.memoryRssBytes).toBe(64 * 1024 * 1024)
    expect(summary.runtimes).toEqual({ node: 1, rust: 1, python: 1 })
    expect(summary.locations).toEqual({ '127.0.0.1': 3 })
    expect(summary.endpoints.map((endpoint) => endpoint.url)).toContain('ws://127.0.0.1:49134')
  })

  it('reports unreachable engines without crashing', () => {
    const summary = buildRuntimeSummary(defaultProfile, {
      reachable: false,
      message: 'connection refused',
    })

    expect(summary.reachable).toBe(false)
    expect(summary.status).toBe('unreachable')
    expect(summary.workerCount).toBe(0)
    expect(summary.resources.metricsAvailable).toBe(false)
    expect(summary.message).toBe('connection refused')
  })
})
