// AppTheme - 应用主题色预设
export interface ThemePreset {
  id: string
  name: string
  primary: string
  light: string
  darkPrimary: string
}

export class AppTheme {
  static readonly PRESETS: ThemePreset[] = [
    { id: 'iris', name: '鸢尾紫', primary: '#5B4BE0', light: '#ECE9FF', darkPrimary: '#A99BFF' },
    { id: 'blue', name: '海蓝', primary: '#2F6FED', light: '#E8F0FF', darkPrimary: '#8AB4FF' },
    { id: 'teal', name: '青绿', primary: '#0F9D8A', light: '#E3F7F2', darkPrimary: '#63D8C7' },
    { id: 'orange', name: '暖橙', primary: '#E56A2F', light: '#FFF0E6', darkPrimary: '#FFB07A' },
    { id: 'rose', name: '玫红', primary: '#D94A82', light: '#FDE8F1', darkPrimary: '#FF8FB6' }
  ]

  static get(id: string): ThemePreset {
    return AppTheme.PRESETS.find((item: ThemePreset): boolean => item.id === id) ?? AppTheme.PRESETS[0]
  }

  static primary(id: string): string {
    return AppTheme.get(id).primary
  }

  static light(id: string): string {
    return AppTheme.get(id).light
  }

  static darkPrimary(id: string): string {
    return AppTheme.get(id).darkPrimary
  }
}
