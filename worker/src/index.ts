import { connectControlEngine, shutdownTargetClients } from './engine-client.js'
import { registerIiiBarFunctions } from './functions.js'

const controlUrl = process.env.IIIBAR_CONTROL_URL || 'ws://127.0.0.1:49134'
const control = connectControlEngine(controlUrl)

registerIiiBarFunctions(control)

console.log(`iiiBar worker connected to ${controlUrl}`)
console.log('Registered iiibar::* functions')

async function shutdown(): Promise<void> {
  await shutdownTargetClients()
  await control.shutdown?.()
  process.exit(0)
}

process.on('SIGINT', () => {
  void shutdown()
})

process.on('SIGTERM', () => {
  void shutdown()
})
