import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'

const DOMAIN: number = 0x0002

// MediaSaveService - 媒体保存服务（真实 Media Library Kit 版本）
export class MediaSaveService {
  private context: common.UIAbilityContext | null = null
  private phAccessHelper: photoAccessHelper.PhotoAccessHelper | null = null

  // 设置上下文
  setContext(context: common.UIAbilityContext): void {
    this.context = context
    try {
      this.phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
    } catch (err) {
      const e: BusinessError = err as BusinessError
      hilog.error(DOMAIN, 'MediaSaveService', `getPhotoAccessHelper failed: ${e.code} ${e.message}`)
    }
  }

  // 保存视频到图库
  async saveVideoToGallery(filePath: string, title: string): Promise<string | null> {
    return this.saveToGallery(filePath, title, photoAccessHelper.PhotoType.VIDEO)
  }

  // 保存图片到图库
  async saveImageToGallery(filePath: string, title: string): Promise<string | null> {
    return this.saveToGallery(filePath, title, photoAccessHelper.PhotoType.IMAGE)
  }

  // 保存到图库（统一实现）
  // 依赖 UI 侧 SaveButton 安全控件：用户点击授权后，本进程获得临时媒体库写权限，
  // 此时调用 createAsset 无需声明受限权限 WRITE_IMAGEVIDEO。
  private async saveToGallery(filePath: string, title: string,
    photoType: photoAccessHelper.PhotoType): Promise<string | null> {
    if (!this.context || !this.phAccessHelper) {
      hilog.error(DOMAIN, 'MediaSaveService', 'saveToGallery: context or phAccessHelper not set')
      return null
    }

    try {
      // 检查源文件是否存在
      if (!fileIo.accessSync(filePath)) {
        hilog.error(DOMAIN, 'MediaSaveService', `Source file not found: ${filePath}`)
        return null
      }

      const extension: string = this.getFileExtension(filePath)
      const options: photoAccessHelper.CreateOptions = {
        title: this.sanitizeTitle(title)
      }

      // 创建媒体资源（需要在 SaveButton 授权有效期内调用）
      const targetUri: string = await this.phAccessHelper.createAsset(photoType, extension, options)
      hilog.info(DOMAIN, 'MediaSaveService', `createAsset uri: ${targetUri}`)

      // 将临时文件内容写入图库
      await this.streamCopyFile(filePath, targetUri)

      hilog.info(DOMAIN, 'MediaSaveService', `Saved to gallery: ${targetUri}`)
      return targetUri
    } catch (err) {
      const e: BusinessError = err as BusinessError
      hilog.error(DOMAIN, 'MediaSaveService', `saveToGallery failed: ${e.code} ${e.message}`)
      return null
    }
  }

  // 打开文件（通过系统文件管理器）
  async openFile(filePath: string): Promise<boolean> {
    if (!this.context) {
      return false
    }

    try {
      if (!fileIo.accessSync(filePath)) {
        hilog.error(DOMAIN, 'MediaSaveService', `File not found: ${filePath}`)
        return false
      }

      // 通过 context 启动 Ability 打开文件
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: `file://${filePath}`,
        type: this.getMimeType(filePath)
      }
      await this.context.startAbility(want)

      return true
    } catch (err) {
      const e: BusinessError = err as BusinessError
      hilog.error(DOMAIN, 'MediaSaveService', `openFile failed: ${e.code} ${e.message}`)
      return false
    }
  }

  // 删除临时文件
  async deleteTempFile(filePath: string): Promise<boolean> {
    try {
      if (filePath.length === 0) {
        return true
      }
      if (fileIo.accessSync(filePath)) {
        fileIo.unlinkSync(filePath)
        hilog.info(DOMAIN, 'MediaSaveService', `Deleted temp file: ${filePath}`)
      }
      return true
    } catch (err) {
      const e: BusinessError = err as BusinessError
      hilog.warn(DOMAIN, 'MediaSaveService', `deleteTempFile failed: ${e.code} ${e.message}`)
      return false
    }
  }

  // 检查文件是否存在
  checkFileExists(filePath: string): boolean {
    try {
      return fileIo.accessSync(filePath)
    } catch (err) {
      return false
    }
  }

  // 获取文件大小
  getFileSize(filePath: string): number {
    try {
      const stat = fileIo.statSync(filePath)
      return stat.size
    } catch (err) {
      return 0
    }
  }

  // ========== 私有辅助方法 ==========

  // 流式复制文件（避免内存峰值）
  private async streamCopyFile(srcPath: string, destUri: string): Promise<void> {
    const BUFFER_SIZE: number = 8192 // 8KB buffer
    let srcFile: fileIo.File | undefined
    let destFile: fileIo.File | undefined

    try {
      srcFile = fileIo.openSync(srcPath, fileIo.OpenMode.READ_ONLY)
      destFile = fileIo.openSync(destUri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)

      let totalRead: number = 0
      let bytesRead: number = 0
      const buffer: ArrayBuffer = new ArrayBuffer(BUFFER_SIZE)

      do {
        bytesRead = fileIo.readSync(srcFile.fd, buffer)
        if (bytesRead > 0) {
          const writeBuffer: ArrayBuffer = bytesRead === BUFFER_SIZE ? buffer : buffer.slice(0, bytesRead)
          fileIo.writeSync(destFile.fd, writeBuffer)
          totalRead += bytesRead
        }
      } while (bytesRead === BUFFER_SIZE)

      hilog.info(DOMAIN, 'MediaSaveService', `Stream copy completed: ${totalRead} bytes`)
    } catch (e) {
      hilog.error(DOMAIN, 'MediaSaveService', `Stream copy failed: ${JSON.stringify(e)}`)
      throw new Error(`Stream copy failed`)
    } finally {
      try {
        if (srcFile) {
          fileIo.closeSync(srcFile)
        }
      } catch (e) {
        // ignore close error
      }
      try {
        if (destFile) {
          fileIo.closeSync(destFile)
        }
      } catch (e) {
        // ignore close error
      }
    }
  }

  private getFileExtension(filePath: string): string {
    const lastDot: number = filePath.lastIndexOf('.')
    if (lastDot > 0) {
      return filePath.substring(lastDot + 1).toLowerCase()
    }
    return 'mp4'
  }

  private getMimeType(filePath: string): string {
    const ext: string = this.getFileExtension(filePath)
    switch (ext) {
      case 'mp4':
        return 'video/mp4'
      case 'gif':
        return 'image/gif'
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg'
      case 'png':
        return 'image/png'
      case 'webp':
        return 'image/webp'
      default:
        return 'application/octet-stream'
    }
  }

  private sanitizeTitle(title: string): string {
    // 移除文件名中不允许的字符
    return title.replace(/[.\\/:*?"'`<>|{}[\]]/g, '_').substring(0, 100)
  }
}
