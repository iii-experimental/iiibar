export const iiiColors = {
  black: '#000000',
  dark: '#1d1d1d',
  medium: '#848484',
  light: '#f4f4f4',
  accent: '#f3f724',
  accentLight: '#2f7fff',
  info: '#42e7e7',
  warn: '#f3943d',
  alert: '#e52e61',
  success: '#1ce669',
} as const

export type IiiColorName = keyof typeof iiiColors

export function colorForStatus(status: string): string {
  switch (status) {
    case 'healthy':
    case 'running':
      return iiiColors.success
    case 'degraded':
    case 'warning':
      return iiiColors.warn
    case 'unreachable':
    case 'stopped':
    case 'error':
      return iiiColors.alert
    default:
      return iiiColors.medium
  }
}
