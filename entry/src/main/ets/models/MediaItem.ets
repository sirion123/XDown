import { ProviderType } from './ResolveResult'

// MediaItem - 历史记录中的媒体项
export class MediaItem {
  id: string = ''
  provider: ProviderType = ProviderType.UNKNOWN
  title: string = ''
  thumbnailUrl: string = ''
  filePath: string = ''
  savedToGallery: boolean = false
  downloadTime: number = 0
  fileSize: number = 0
  fileExists: boolean = true

  constructor(id: string, provider: ProviderType, title: string,
    thumbnailUrl: string, filePath: string, savedToGallery: boolean,
    downloadTime: number, fileSize: number, fileExists: boolean) {
    this.id = id
    this.provider = provider
    this.title = title
    this.thumbnailUrl = thumbnailUrl
    this.filePath = filePath
    this.savedToGallery = savedToGallery
    this.downloadTime = downloadTime
    this.fileSize = fileSize
    this.fileExists = fileExists
  }
}
