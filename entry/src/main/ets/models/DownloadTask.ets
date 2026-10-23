import { ProviderType } from './ResolveResult'

// DownloadStatus - 下载任务状态
export enum DownloadStatus {
  QUEUED = 'queued',
  RESOLVING = 'resolving',
  DOWNLOADING = 'downloading',
  SAVING = 'saving',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
}

// DownloadTask - 下载任务
@Observed
export class DownloadTask {
  taskId: string = ''
  status: DownloadStatus = DownloadStatus.QUEUED
  progress: number = 0
  targetFilePath: string = ''
  errorCode: string = ''
  errorMsg: string = ''
  createdAt: number = 0
  provider: ProviderType = ProviderType.UNKNOWN
  title: string = ''
  formatId: string = ''
  totalBytes: number = 0
  downloadedBytes: number = 0
  speed: number = 0
  downloadUrl: string = ''
  // 下载请求头（如 X CDN 需要的 Referer / User-Agent / Cookie）
  requestHeaders: Record<string, string> | null = null

  constructor(taskId: string, provider: ProviderType, title: string,
    formatId: string, createdAt: number) {
    this.taskId = taskId
    this.provider = provider
    this.title = title
    this.formatId = formatId
    this.createdAt = createdAt
  }
}
