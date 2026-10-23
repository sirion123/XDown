import { DownloadTask, DownloadStatus } from '../models/DownloadTask'
import { ProviderType } from '../models/ResolveResult'
import { MediaItem } from '../models/MediaItem'
import { HistoryRepository } from '../storage/HistoryRepository'
import { BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import statvfs from '@ohos.file.statvfs'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x0001

// DownloadService - 下载服务
// 使用 @kit.NetworkKit 的 http 流式下载，而不是 request.agent：
// request.agent 走系统下载进程，实测在 VPN/代理下会因 SSL 证书校验失败（SslErrorCode 5），
// 且无法与解析请求共用同一套网络栈。http 流式下载与解析同栈，便于透传 Referer/Cookie。
export class DownloadService {
  private tasks: Map<string, DownloadTask> = new Map()
  private httpRequests: Map<string, http.HttpRequest> = new Map()
  private openFiles: Map<string, fileIo.File> = new Map()
  private taskCounter: number = 0
  private context: common.UIAbilityContext | null = null

  // 设置上下文（必须在创建下载任务前调用）
  setContext(context: common.UIAbilityContext): void {
    this.context = context
  }

  // 创建下载任务
  createTask(provider: ProviderType, title: string, formatId: string, downloadUrl: string,
    requestHeaders: Record<string, string> | null = null): DownloadTask {
    this.taskCounter++
    const taskId: string = `task_${Date.now()}_${this.taskCounter}`
    const task: DownloadTask = new DownloadTask(taskId, provider, title, formatId, Date.now())
    task.status = DownloadStatus.QUEUED
    task.downloadUrl = downloadUrl
    task.requestHeaders = requestHeaders
    this.tasks.set(taskId, task)
    return task
  }

  // 获取所有任务
  getAllTasks(): DownloadTask[] {
    return Array.from(this.tasks.values()).sort((a: DownloadTask, b: DownloadTask): number => b.createdAt - a.createdAt)
  }

  // 获取指定任务
  getTask(taskId: string): DownloadTask | undefined {
    return this.tasks.get(taskId)
  }

  // 开始下载
  async startDownload(taskId: string): Promise<void> {
    const task: DownloadTask | undefined = this.tasks.get(taskId)
    if (!task || !this.context) {
      hilog.error(DOMAIN, 'DownloadService', 'startDownload: task or context not found')
      return
    }
    if (task.status === DownloadStatus.DOWNLOADING) {
      return
    }

    // 清理上一轮残留的请求/文件句柄
    this.abortRequest(taskId)

    task.status = DownloadStatus.DOWNLOADING
    task.errorCode = ''
    task.errorMsg = ''
    task.progress = 0
    task.downloadedBytes = 0
    task.totalBytes = 0
    task.speed = 0

    const fileName: string = this.buildFileName(task)
    const targetPath: string = `${this.context.cacheDir}/downloads/${fileName}`
    const tempPath: string = `${targetPath}.part`

    try {
      this.ensureDownloadDir()
      // 部分 CDN 会返回 http:// 的地址，统一升级到 https://。
      const schemeIdx: number = task.downloadUrl.indexOf('://')
      const downloadUrl: string = schemeIdx >= 0 ?
        `https://${task.downloadUrl.substring(schemeIdx + 3)}` : task.downloadUrl
      task.downloadUrl = downloadUrl
      const host: string = downloadUrl.replace(/^https?:\/\//, '').split('/')[0]
      hilog.info(DOMAIN, 'DownloadService', 'Task %{public}s downloading from host: %{public}s', taskId, host)

      const hasSpace: boolean = await this.checkDiskSpace(100 * 1024 * 1024)
      if (!hasSpace) {
        this.failTask(task, 'insufficient_disk_space', '磁盘空间不足，请清理后重试')
        return
      }
      if (task.status !== DownloadStatus.DOWNLOADING) {
        return
      }

      this.unlinkQuietly(tempPath)
      const file: fileIo.File = fileIo.openSync(tempPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      this.openFiles.set(taskId, file)

      const httpRequest: http.HttpRequest = http.createHttp()
      this.httpRequests.set(taskId, httpRequest)

      let received: number = 0
      let lastBytes: number = 0
      let lastTime: number = Date.now()

      httpRequest.on('dataReceive', (data: ArrayBuffer): void => {
        if (task.status !== DownloadStatus.DOWNLOADING) {
          return
        }
        try {
          fileIo.writeSync(file.fd, data)
          received += data.byteLength
          task.downloadedBytes = received
          this.updateProgress(task, received, lastBytes, lastTime)
          lastBytes = received
          lastTime = Date.now()
        } catch (err) {
          hilog.error(DOMAIN, 'DownloadService', `Write chunk failed: ${JSON.stringify(err)}`)
          this.failTask(task, 'file_write_failed', '写入下载文件失败')
        }
      })

      httpRequest.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo): void => {
        if (task.status !== DownloadStatus.DOWNLOADING) {
          return
        }
        if (info.totalSize > 0) {
          task.totalBytes = info.totalSize
        }
        // 某些 CDN 在 dataReceiveProgress 先到，dataReceive 计数为 0 时用它校正
        if (received === 0 && info.receiveSize > 0) {
          received = info.receiveSize
          task.downloadedBytes = received
        }
        this.updateProgress(task, received, lastBytes, lastTime)
      })

      const headers: Record<string, string> = this.buildHeaders(task)
      const responseCode: number = await httpRequest.requestInStream(downloadUrl, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 15000,
        readTimeout: 60000,
        usingCache: false,
        maxRedirects: 5
      })

      // 用户可能已经暂停/取消
      if (task.status !== DownloadStatus.DOWNLOADING) {
        return
      }

      if (responseCode < 200 || responseCode >= 300) {
        const message: string = responseCode === 403 ?
          'CDN 拒绝访问（403）：可能需要先登录平台，或签名地址与代理出口不匹配' :
          `服务器返回 HTTP ${responseCode}`
        this.failTask(task, `http_status_${responseCode}`, message)
        return
      }

      this.closeFile(taskId)
      this.destroyRequest(taskId)

      if (fileIo.accessSync(targetPath)) {
        this.unlinkQuietly(targetPath)
      }
      fileIo.renameSync(tempPath, targetPath)
      task.targetFilePath = targetPath
      task.progress = 100
      task.status = DownloadStatus.COMPLETED
      task.speed = 0
      if (task.totalBytes <= 0) {
        try {
          task.totalBytes = fileIo.statSync(targetPath).size
        } catch (err) {
          task.totalBytes = 0
        }
      }
      this.recordHistory(task)
      hilog.info(DOMAIN, 'DownloadService', `Task ${taskId} completed: ${targetPath}`)
    } catch (err) {
      // 暂停/取消触发的 destroy 也会进入 catch，此时状态已不是 DOWNLOADING
      if (task.status !== DownloadStatus.DOWNLOADING) {
        return
      }
      const e: BusinessError = err as BusinessError
      this.failTask(task, `http_${e.code ?? 0}`, `下载失败：${e.message ?? '网络错误'} (${e.code ?? 0})`)
    } finally {
      this.closeFile(taskId)
      this.destroyRequest(taskId)
    }
  }

  // 暂停任务：停止当前 HTTP 请求，保留排队状态；继续时从头开始（避免服务端不支持 Range 导致文件损坏）
  async pauseTask(taskId: string): Promise<void> {
    const task: DownloadTask | undefined = this.tasks.get(taskId)
    if (!task || task.status !== DownloadStatus.DOWNLOADING) {
      return
    }
    task.status = DownloadStatus.QUEUED
    task.speed = 0
    this.abortRequest(taskId)
    hilog.info(DOMAIN, 'DownloadService', `Task ${taskId} paused`)
  }

  // 继续任务
  async resumeTask(taskId: string): Promise<void> {
    const task: DownloadTask | undefined = this.tasks.get(taskId)
    if (!task || task.status !== DownloadStatus.QUEUED) {
      return
    }
    task.downloadedBytes = 0
    task.progress = 0
    await this.startDownload(taskId)
  }

  // 取消任务：停止请求并删除临时文件
  async cancelTask(taskId: string): Promise<void> {
    const task: DownloadTask | undefined = this.tasks.get(taskId)
    if (!task) {
      return
    }
    task.status = DownloadStatus.CANCELLED
    task.speed = 0
    this.abortRequest(taskId)
    this.unlinkQuietly(`${this.targetPath(task)}.part`)
    hilog.info(DOMAIN, 'DownloadService', `Task ${taskId} cancelled`)
  }

  // 重试任务
  async retryTask(taskId: string): Promise<void> {
    const task: DownloadTask | undefined = this.tasks.get(taskId)
    if (!task) {
      return
    }
    if (task.status === DownloadStatus.FAILED || task.status === DownloadStatus.CANCELLED) {
      task.status = DownloadStatus.QUEUED
      task.progress = 0
      task.downloadedBytes = 0
      task.errorCode = ''
      task.errorMsg = ''
      await this.startDownload(taskId)
    }
  }

  // 删除任务（同时清理文件）
  async deleteTask(taskId: string): Promise<void> {
    const task: DownloadTask | undefined = this.tasks.get(taskId)
    if (!task) {
      return
    }
    await this.cancelTask(taskId)
    this.unlinkQuietly(task.targetFilePath)
    this.unlinkQuietly(`${this.targetPath(task)}.part`)
    this.tasks.delete(taskId)
  }

  // 清理已结束的任务（完成/失败/取消），不删除图库文件
  clearFinishedTasks(): void {
    const finished: string[] = []
    this.tasks.forEach((task: DownloadTask, taskId: string) => {
      if (task.status === DownloadStatus.COMPLETED ||
        task.status === DownloadStatus.FAILED ||
        task.status === DownloadStatus.CANCELLED) {
        finished.push(taskId)
      }
    })
    for (const taskId of finished) {
      this.tasks.delete(taskId)
    }
  }

  // 检查重复任务
  isDuplicateTask(provider: ProviderType, title: string): boolean {
    for (const task of this.tasks.values()) {
      if (task.provider === provider && task.title === title &&
        task.status !== DownloadStatus.FAILED && task.status !== DownloadStatus.CANCELLED) {
        return true
      }
    }
    return false
  }

  // 检查磁盘空间
  async checkDiskSpace(requiredBytes: number): Promise<boolean> {
    if (!this.context) {
      return true
    }
    try {
      const path: string = this.context.filesDir
      const freeBytes: number = await statvfs.getFreeSize(path)
      hilog.info(DOMAIN, 'DownloadService', `Free disk space: ${freeBytes} bytes, required: ${requiredBytes}`)
      return freeBytes >= requiredBytes
    } catch (err) {
      hilog.warn(DOMAIN, 'DownloadService', `Failed to check disk space: ${JSON.stringify(err)}`)
      return true
    }
  }

  // ========== 私有辅助方法 ==========

  private buildFileName(task: DownloadTask): string {
    const safeTitle: string = task.title.replace(/[<>:"/\\|?*]/g, '_').substring(0, 50)
    const ext: string = task.formatId.includes('mp4') ? 'mp4' :
      task.formatId.includes('gif') ? 'gif' : 'mp4'
    return `${task.provider}_${safeTitle}_${task.taskId}.${ext}`
  }

  private targetPath(task: DownloadTask): string {
    if (!this.context) {
      return ''
    }
    return `${this.context.cacheDir}/downloads/${this.buildFileName(task)}`
  }

  private ensureDownloadDir(): void {
    if (!this.context) {
      return
    }
    const dirPath: string = `${this.context.cacheDir}/downloads`
    try {
      if (!fileIo.accessSync(dirPath)) {
        fileIo.mkdirSync(dirPath, true)
      }
    } catch (err) {
      try {
        fileIo.mkdirSync(dirPath, true)
      } catch (e) {
        hilog.error(DOMAIN, 'DownloadService', `Create download dir failed: ${dirPath}`)
      }
    }
  }

  private normalizeCookie(raw: string): string {
    const attributes: string[] = ['path', 'domain', 'expires', 'max-age', 'secure', 'httponly', 'samesite']
    const pairs: string[] = []
    const parts: string[] = raw.split(/[;,]/)
    for (const part of parts) {
      const segment: string = part.trim()
      const eq: number = segment.indexOf('=')
      if (eq <= 0) {
        continue
      }
      const name: string = segment.substring(0, eq).trim()
      if (name.length === 0 || attributes.indexOf(name.toLowerCase()) >= 0) {
        continue
      }
      pairs.push(segment)
    }
    return pairs.join('; ')
  }

  private buildHeaders(task: DownloadTask): Record<string, string> {
    const headers: Record<string, string> = {}
    if (task.requestHeaders) {
      const source: Record<string, string> = task.requestHeaders
      for (const key of Object.keys(source)) {
        // Cookie 由响应头 Set-Cookie 拼接而来，可能夹带 Path/Domain 等属性；
        // 规范化成 name=value; name2=value2，避免把属性当 Cookie 发给 CDN。
        if (key.toLowerCase() === 'cookie') {
          const cookie: string = this.normalizeCookie(source[key])
          if (cookie.length > 0) {
            headers['Cookie'] = cookie
          }
          continue
        }
        // Header 值里如果带控制字符/非 ASCII，libcurl 会以 CURLE_BAD_FUNCTION_ARGUMENT(43) 失败
        const cleanValue: string = source[key]
          .replace(/[\u0000-\u001F\u007F-\uFFFF]/g, '')
          .trim()
        if (key.length > 0 && cleanValue.length > 0) {
          headers[key] = cleanValue
        }
      }
    }
    if (!headers['User-Agent'] && !headers['user-agent']) {
      headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 ' +
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
    }
    if (!headers['Accept']) {
      headers['Accept'] = '*/*'
    }
    // 视频是二进制，避免服务端 gzip 后按文本解码
    if (!headers['Accept-Encoding'] && !headers['accept-encoding']) {
      headers['Accept-Encoding'] = 'identity'
    }
    return headers
  }

  private updateProgress(task: DownloadTask, received: number, lastBytes: number, lastTime: number): void {
    if (task.totalBytes > 0) {
      task.progress = Math.min(99, Math.floor((received / task.totalBytes) * 100))
    }
    const now: number = Date.now()
    const elapsed: number = now - lastTime
    if (elapsed > 0) {
      task.speed = Math.max(0, Math.floor((received - lastBytes) / (elapsed / 1000)))
    }
  }

  private failTask(task: DownloadTask, code: string, message: string): void {
    task.status = DownloadStatus.FAILED
    task.errorCode = code
    task.errorMsg = message
    task.speed = 0
    this.abortRequest(task.taskId)
    hilog.error(DOMAIN, 'DownloadService', `Task ${task.taskId} failed: ${code} ${message}`)
  }

  private abortRequest(taskId: string): void {
    this.destroyRequest(taskId)
    this.closeFile(taskId)
  }

  private destroyRequest(taskId: string): void {
    const req: http.HttpRequest | undefined = this.httpRequests.get(taskId)
    if (req) {
      try {
        req.destroy()
      } catch (err) {
        // 忽略已销毁
      }
      this.httpRequests.delete(taskId)
    }
  }

  private closeFile(taskId: string): void {
    const file: fileIo.File | undefined = this.openFiles.get(taskId)
    if (file) {
      try {
        fileIo.closeSync(file)
      } catch (err) {
        // 忽略
      }
      this.openFiles.delete(taskId)
    }
  }

  private unlinkQuietly(path: string): void {
    if (path.length === 0) {
      return
    }
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path)
      }
    } catch (err) {
      // 忽略
    }
  }

  // 历史记录 id 约定：hist_<taskId>（供页面更新"已保存到图库"状态）
  static historyId(taskId: string): string {
    return `hist_${taskId}`
  }

  // 下载完成后写入历史记录
  private recordHistory(task: DownloadTask): void {
    try {
      const repo: HistoryRepository | undefined = AppStorage.get<HistoryRepository>('historyRepository')
      if (!repo) {
        return
      }
      let size: number = task.totalBytes
      if (size <= 0 && task.targetFilePath.length > 0) {
        try {
          size = fileIo.statSync(task.targetFilePath).size
        } catch (e) {
          size = 0
        }
      }
      const item: MediaItem = new MediaItem(
        DownloadService.historyId(task.taskId),
        task.provider,
        task.title,
        '',
        task.targetFilePath,
        false,
        Date.now(),
        size,
        true
      )
      repo.addItem(item)
    } catch (err) {
      hilog.warn(DOMAIN, 'DownloadService', `recordHistory failed: ${JSON.stringify(err)}`)
    }
  }
}
