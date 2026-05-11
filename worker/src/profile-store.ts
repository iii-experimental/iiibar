import { defaultProfile, normalizeProfile, stateScope } from './defaults.js'
import type { IiiClient } from './engine-client.js'
import type { EngineProfile, ProfileListResult } from './types.js'

export async function listProfiles(control: IiiClient): Promise<ProfileListResult> {
  try {
    const profiles = await control.trigger<{ scope: string }, EngineProfile[]>({
      function_id: 'state::list',
      payload: { scope: stateScope },
      timeoutMs: 3000,
    })
    const normalized = profiles.map((profile) => normalizeProfile(profile))
    return {
      profiles: normalized.length ? normalized : [defaultProfile],
      stateAvailable: true,
    }
  } catch (error) {
    return {
      profiles: [defaultProfile],
      stateAvailable: false,
      warning: error instanceof Error ? error.message : String(error),
    }
  }
}

export async function saveProfile(control: IiiClient, input: Partial<EngineProfile>): Promise<EngineProfile> {
  const profile = normalizeProfile(input)
  await control.trigger<{ scope: string; key: string; value: EngineProfile }, unknown>({
    function_id: 'state::set',
    payload: {
      scope: stateScope,
      key: profile.id,
      value: profile,
    },
    timeoutMs: 3000,
  })
  return profile
}

export async function resolveProfile(
  control: IiiClient,
  input: { profile?: Partial<EngineProfile>; profileId?: string },
): Promise<EngineProfile> {
  if (input.profile) return normalizeProfile(input.profile)
  const list = await listProfiles(control)
  const id = input.profileId || list.profiles[0]?.id || defaultProfile.id
  return list.profiles.find((profile) => profile.id === id) || defaultProfile
}

export async function resolveStoredProfile(
  control: IiiClient,
  input: { profile?: Partial<EngineProfile>; profileId?: string },
): Promise<EngineProfile> {
  if (input.profile) {
    throw new Error('Lifecycle actions require a saved profileId.')
  }
  const list = await listProfiles(control)
  const id = input.profileId || list.profiles[0]?.id || defaultProfile.id
  const profile = list.profiles.find((entry) => entry.id === id)
  if (!profile) {
    throw new Error(`Profile ${id} was not found.`)
  }
  return profile
}
