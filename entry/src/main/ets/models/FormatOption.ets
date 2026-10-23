// FormatOption - 可下载的格式选项
export class FormatOption {
  id: string = ''
  label: string = ''
  width: number = 0
  height: number = 0
  sizeBytes: number | null = null
  downloadMode: DownloadMode = DownloadMode.DIRECT
  downloadUrl: string | null = null
  requestHeaders: Record<string, string> | null = null

  constructor(id: string, label: string, width: number, height: number,
    sizeBytes: number | null, downloadMode: DownloadMode, downloadUrl: string | null = null,
    requestHeaders: Record<string, string> | null = null) {
    this.id = id
    this.label = label
    this.width = width
    this.height = height
    this.sizeBytes = sizeBytes
    this.downloadMode = downloadMode
    this.downloadUrl = downloadUrl
    this.requestHeaders = requestHeaders
  }
}

export enum DownloadMode {
  DIRECT = 'direct'
}
