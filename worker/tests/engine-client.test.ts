import { beforeEach, describe, expect, it, vi } from 'vitest'
import { defaultProfile } from '../src/defaults.js'

const clients: MockClient[] = []
const registerWorker = vi.fn((url: string) => {
  const client: MockClient = {
    url,
    trigger: vi.fn(async (request: unknown) => ({ url, request })),
    registerFunction: vi.fn(),
    registerService: vi.fn(),
    registerTrigger: vi.fn(),
    registerTriggerType: vi.fn(),
    unregisterTriggerType: vi.fn(),
    createChannel: vi.fn(),
    shutdown: vi.fn(),
  }
  clients.push(client)
  return client
})

vi.mock('iii-sdk', () => ({ registerWorker }))

type MockClient = {
  url: string
  trigger: ReturnType<typeof vi.fn>
  registerFunction: ReturnType<typeof vi.fn>
  registerService: ReturnType<typeof vi.fn>
  registerTrigger: ReturnType<typeof vi.fn>
  registerTriggerType: ReturnType<typeof vi.fn>
  unregisterTriggerType: ReturnType<typeof vi.fn>
  createChannel: ReturnType<typeof vi.fn>
  shutdown: ReturnType<typeof vi.fn>
}

describe('engine client routing', () => {
  beforeEach(() => {
    clients.length = 0
    registerWorker.mockClear()
    vi.resetModules()
  })

  it('reuses the control worker for the selected local engine', async () => {
    const { connectControlEngine, getTargetEngine } = await import('../src/engine-client.js')

    const control = connectControlEngine('ws://127.0.0.1:49134')
    const target = getTargetEngine(defaultProfile)

    expect(target).toBe(control)
    expect(registerWorker).toHaveBeenCalledTimes(1)
  })

  it('routes bridge profiles through the bridge invoke primitive', async () => {
    const { connectControlEngine, triggerEngine } = await import('../src/engine-client.js')
    const control = connectControlEngine('ws://127.0.0.1:49134')

    await triggerEngine(
      {
        ...defaultProfile,
        id: 'remote-through-bridge',
        kind: 'remote',
        transport: 'bridge',
        bridgeInvokeFunctionId: 'bridge.invoke',
      },
      {
        function_id: 'engine::health::check',
        payload: {},
        timeoutMs: 1234,
      },
    )

    expect(registerWorker).toHaveBeenCalledTimes(1)
    expect(control.trigger).toHaveBeenCalledWith({
      function_id: 'bridge.invoke',
      payload: {
        function_id: 'engine::health::check',
        data: {},
        timeout_ms: 1234,
      },
      timeoutMs: 1234,
    })
  })
})
