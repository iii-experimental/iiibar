import { registerWorker, type ISdk, type InitOptions, type TriggerRequest } from 'iii-sdk'
import { wsUrl } from './defaults.js'
import type { EngineProfile } from './types.js'

export type IiiClient = ISdk

const targetClients = new Map<string, IiiClient>()
let controlClient: IiiClient | undefined
let controlEngineUrl: string | undefined

export function connectControlEngine(url: string): IiiClient {
  const client = registerWorker(url, {
    workerName: 'iiiBar worker',
    otel: {
      enabled: true,
      serviceName: 'iiibar-worker',
      serviceVersion: '0.2.3',
    },
    telemetry: {
      project_name: 'iiibar',
      framework: 'iiiBar',
      language: 'typescript',
    },
  } as InitOptions)
  controlClient = client
  controlEngineUrl = url
  return client
}

export async function triggerEngine<TInput, TOutput>(
  profile: EngineProfile,
  request: TriggerRequest<TInput>,
): Promise<TOutput> {
  const control = requireControlClient()
  if (profile.transport === 'bridge') {
    return control.trigger<BridgeInvokePayload<TInput>, TOutput>({
      function_id: profile.bridgeInvokeFunctionId || 'bridge.invoke',
      payload: {
        function_id: request.function_id,
        data: request.payload,
        timeout_ms: request.timeoutMs,
      },
      timeoutMs: request.timeoutMs,
    })
  }
  return getTargetEngine(profile).trigger<TInput, TOutput>(request)
}

export function getTargetEngine(profile: EngineProfile): IiiClient {
  const control = requireControlClient()
  const key = wsUrl(profile)
  if (isSameEngineUrl(key, controlEngineUrl)) return control
  const existing = targetClients.get(key)
  if (existing) return existing
  const client = registerWorker(key, {
    workerName: `iiiBar monitor ${profile.id}`,
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

type BridgeInvokePayload<TInput> = {
  function_id: string
  data: TInput
  timeout_ms?: number
}

function requireControlClient(): IiiClient {
  if (!controlClient) {
    throw new Error('iiiBar control worker is not connected.')
  }
  return controlClient
}

function isSameEngineUrl(left: string, right?: string): boolean {
  if (!right) return false
  const a = parseWsUrl(left)
  const b = parseWsUrl(right)
  if (!a || !b) return left === right
  return a.protocol === b.protocol && a.port === b.port && normalizeHost(a.hostname) === normalizeHost(b.hostname)
}

function parseWsUrl(value: string): URL | undefined {
  try {
    return new URL(value)
  } catch {
    return undefined
  }
}

function normalizeHost(host: string): string {
  const normalized = host.replace(/^\[|\]$/g, '').toLowerCase()
  return normalized === 'localhost' || normalized === '127.0.0.1' || normalized === '::1' ? 'local' : normalized
}
