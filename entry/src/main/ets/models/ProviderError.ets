// ProviderError - 解析错误
export class ProviderError {
  code: ErrorCode = ErrorCode.UNKNOWN
  message: string = ''
  retryable: boolean = false

  constructor(code: ErrorCode, message: string, retryable: boolean) {
    this.code = code
    this.message = message
    this.retryable = retryable
  }
}

export enum ErrorCode {
  UNSUPPORTED = 'unsupported',
  RATE_LIMITED = 'rate_limited',
  TIMEOUT = 'timeout',
  OFFLINE = 'offline',
  LOGIN_REQUIRED = 'login_required',
  NOT_FOUND = 'not_found',
  NO_VIDEO = 'no_video',
  ACCESS_RESTRICTED = 'access_restricted',
  PROVIDER_ERROR = 'provider_error',
  PROVIDER_TIMEOUT = 'provider_timeout',
  PROVIDER_RATE_LIMITED = 'provider_rate_limited',
  UNKNOWN = 'unknown'
}
