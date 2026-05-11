import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process'
import type { EngineProfile, ProcessState } from './types.js'

const processes = new Map<string, { child: ChildProcessWithoutNullStreams; startedAt: string }>()

export function startEngine(profile: EngineProfile): ProcessState {
  if (process.env.IIIBAR_ENABLE_LIFECYCLE !== '1') {
    return {
      profileId: profile.id,
      running: false,
      message: 'Lifecycle actions are disabled. Set IIIBAR_ENABLE_LIFECYCLE=1 to allow local engine start.',
    }
  }

  if (profile.kind !== 'local') {
    return {
      profileId: profile.id,
      running: false,
      message: 'Only local profiles can be started by iiiBar.',
    }
  }

  if (!profile.binaryPath) {
    return {
      profileId: profile.id,
      running: false,
      message: 'Local profile is missing binaryPath.',
    }
  }

  const existing = processes.get(profile.id)
  if (existing && !existing.child.killed) {
    return {
      profileId: profile.id,
      running: true,
      pid: existing.child.pid,
      startedAt: existing.startedAt,
      message: 'Engine is already managed by iiiBar.',
    }
  }

  const args = profile.configPath ? ['--config', profile.configPath] : ['--use-default-config']
  const child = spawn(profile.binaryPath, args, {
    cwd: profile.workingDirectory || process.cwd(),
    env: { ...process.env, ...profile.env },
    stdio: 'pipe',
  })
  const startedAt = new Date().toISOString()
  processes.set(profile.id, { child, startedAt })
  child.once('exit', () => {
    processes.delete(profile.id)
  })

  return {
    profileId: profile.id,
    running: true,
    pid: child.pid,
    startedAt,
    message: `Started ${profile.name}.`,
  }
}

export function stopEngine(profile: EngineProfile): ProcessState {
  const managed = processes.get(profile.id)
  if (!managed) {
    return {
      profileId: profile.id,
      running: false,
      stoppedAt: new Date().toISOString(),
      message: 'No iiiBar-managed process is running for this profile.',
    }
  }

  managed.child.kill('SIGTERM')
  processes.delete(profile.id)
  return {
    profileId: profile.id,
    running: false,
    pid: managed.child.pid,
    startedAt: managed.startedAt,
    stoppedAt: new Date().toISOString(),
    message: `Stopped ${profile.name}.`,
  }
}

export function processState(profile: EngineProfile): ProcessState {
  const managed = processes.get(profile.id)
  return {
    profileId: profile.id,
    running: Boolean(managed && !managed.child.killed),
    pid: managed?.child.pid,
    startedAt: managed?.startedAt,
  }
}
