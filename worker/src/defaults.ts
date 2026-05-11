import type { EngineProfile } from './types.js'

export const stateScope = 'iiibar.profiles'

export const defaultProfile: EngineProfile = {
  id: 'local-default',
  name: 'Local iii',
  kind: 'local',
  host: '127.0.0.1',
  httpPort: 3111,
  bridgePort: 49134,
  streamPort: 3112,
  pollingIntervalSeconds: 5,
}

export function normalizeProfile(input: Partial<EngineProfile>): EngineProfile {
  const id = sanitizeId(input.id || input.name || defaultProfile.id)
  return {
    ...defaultProfile,
    ...input,
    id,
    name: input.name?.trim() || id,
    kind: input.kind === 'remote' ? 'remote' : 'local',
    transport: input.transport === 'bridge' ? 'bridge' : 'direct',
    host: input.host?.trim() || defaultProfile.host,
    httpPort: normalizePort(input.httpPort, defaultProfile.httpPort),
    bridgePort: normalizePort(input.bridgePort, defaultProfile.bridgePort),
    streamPort: normalizePort(input.streamPort, defaultProfile.streamPort),
    bridgeInvokeFunctionId: input.bridgeInvokeFunctionId?.trim() || undefined,
    pollingIntervalSeconds: Math.max(1, Number(input.pollingIntervalSeconds || 5)),
  }
}

export function wsUrl(profile: EngineProfile): string {
  return `ws://${profile.host}:${profile.bridgePort}`
}

function normalizePort(value: unknown, fallback: number): number {
  const port = Number(value)
  if (!Number.isInteger(port) || port <= 0 || port > 65535) return fallback
  return port
}

function sanitizeId(value: string): string {
  const id = value.trim().toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '')
  return id || defaultProfile.id
}
