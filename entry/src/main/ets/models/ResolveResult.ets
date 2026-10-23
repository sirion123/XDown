import { FormatOption } from './FormatOption'
import { ProviderError } from './ProviderError'

// WatermarkStatus - 水印状态
export enum WatermarkStatus {
  CONFIRMED_CLEAN = 'confirmed_clean',
  WATERMARKED = 'watermarked',
  UNKNOWN = 'unknown'
}

// ProviderType - 平台类型
// 当前仅开放 X；未来接入新平台时在此追加枚举，并在 ResolveService 中注册对应 Provider。
export enum ProviderType {
  X = 'x',
  UNKNOWN = 'unknown'
}

// ResolveResult - 解析结果
export class ResolveResult {
  provider: ProviderType = ProviderType.UNKNOWN
  canonicalUrl: string = ''
  title: string = ''
  author: string = ''
  thumbnailUrl: string = ''
  durationSeconds: number = 0
  formats: FormatOption[] = []
  watermarkStatus: WatermarkStatus = WatermarkStatus.UNKNOWN
  warnings: string[] = []
  expiresAt: number | null = null

  constructor(provider: ProviderType, canonicalUrl: string, title: string,
    author: string, thumbnailUrl: string, durationSeconds: number,
    formats: FormatOption[], watermarkStatus: WatermarkStatus,
    warnings: string[], expiresAt: number | null) {
    this.provider = provider
    this.canonicalUrl = canonicalUrl
    this.title = title
    this.author = author
    this.thumbnailUrl = thumbnailUrl
    this.durationSeconds = durationSeconds
    this.formats = formats
    this.watermarkStatus = watermarkStatus
    this.warnings = warnings
    this.expiresAt = expiresAt
  }
}

// ResolveResultOrError - 解析结果或错误的联合类型
export class ResolveResultOrError {
  result: ResolveResult | null = null
  error: ProviderError | null = null

  constructor(result: ResolveResult | null, error: ProviderError | null) {
    this.result = result
    this.error = error
  }

  isSuccess(): boolean {
    return this.result !== null
  }
}
