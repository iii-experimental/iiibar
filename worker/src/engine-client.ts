import { registerWorker, type InitOptions } from 'iii-sdk'
import { wsUrl } from './defaults.js'
import type { EngineProfile } from './types.js'

export type IiiLikeClient = {
  trigger<TInput, TOutput>(request: {
    function_id: string
    payload: TInput
    timeoutMs?: number
  }): Promise<TOutput>
  registerFunction?<TInput, TOutput>(
    functionId: string,
    handler: (input: TInput) => Promise<TOutput>,
    options?: { description?: string },
  ): unknown
  registerService?(input: { id: string; name?: string; description?: string }): void
  shutdown?(): Promise<void>
}

const targetClients = new Map<string, IiiLikeClient>()

export function connectControlEngine(url: string): IiiLikeClient {
  return registerWorker(url, {
    workerName: 'iiiBar worker',
    otel: {
      enabled: true,
      serviceName: 'iiibar-worker',
      serviceVersion: '0.1.0',
    },
    telemetry: {
      project_name: 'iiibar',
      framework: 'iiiBar',
      language: 'typescript',
    },
  } as InitOptions)
}

export function getTargetEngine(profile: EngineProfile): IiiLikeClient {
  const key = wsUrl(profile)
  const existing = targetClients.get(key)
  if (existing) return existing
  const client = registerWorker(key, {
    workerName: `iiiBar target ${profile.id}`,
    invocationTimeoutMs: 5000,
    enableMetricsReporting: false,
    otel: {
      enabled: false,
    },
    reconnectionConfig: {
      maxRetries: 0,
    },
  } as InitOptions)
  targetClients.set(key, client)
  return client
}

export async function shutdownTargetClients(): Promise<void> {
  await Promise.all([...targetClients.values()].map((client) => client.shutdown?.()))
  targetClients.clear()
}
