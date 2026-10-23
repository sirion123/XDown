import { ProviderAdapter } from './ProviderAdapter'
import { ResolveResult, ProviderType, WatermarkStatus } from '../models/ResolveResult'
import { ProviderError, ErrorCode } from '../models/ProviderError'
import { FormatOption, DownloadMode } from '../models/FormatOption'
import { http } from '@kit.NetworkKit'

const X_USER_AGENT: string =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
const X_REFERER: string = 'https://x.com/'
const X_SYNDICATION_API: string = 'https://cdn.syndication.twimg.com/tweet-result'
const X_GRAPHQL_API: string = 'https://x.com/i/api/graphql'
// X web GraphQL query id; may rotate, fallback to syndication when stale.
const X_TWEET_RESULT_QID: string = 'V3vfsYzNEyD9tsf4xoFRgw'
const X_BEARER: string =
  'AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA'

interface XFeatures {
  creator_subscriptions_tweet_preview_api_enabled: boolean
  c9s_tweet_anatomy_moderator_badge_enabled: boolean
  tweetypie_unmention_optimization_enabled: boolean
  responsive_web_edit_tweet_api_enabled: boolean
  graphql_is_translatable_rweb_tweet_is_translatable_enabled: boolean
  view_counts_everywhere_api_enabled: boolean
  longform_notetweets_consumption_enabled: boolean
  responsive_web_twitter_article_tweet_consumption_enabled: boolean
  tweet_awards_web_tipping_enabled: boolean
  longform_notetweets_rich_text_read_enabled: boolean
  longform_notetweets_inline_media_enabled: boolean
  rweb_video_timestamps_enabled: boolean
  responsive_web_graphql_exclude_directive_enabled: boolean
  verified_phone_label_enabled: boolean
  freedom_of_speech_not_reach_fetch_enabled: boolean
  standardized_nudges_misinfo: boolean
  tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled: boolean
  responsive_web_media_download_video_enabled: boolean
  responsive_web_graphql_skip_user_profile_image_extensions_enabled: boolean
  responsive_web_graphql_timeline_navigation_enabled: boolean
  responsive_web_enhance_cards_enabled: boolean
}

interface XGraphQLVariables {
  tweetId: string
  withCommunity: boolean
  includePromotedContent: boolean
  withVoice: boolean
}

const X_FEATURES: XFeatures = {
  creator_subscriptions_tweet_preview_api_enabled: true,
  c9s_tweet_anatomy_moderator_badge_enabled: true,
  tweetypie_unmention_optimization_enabled: true,
  responsive_web_edit_tweet_api_enabled: true,
  graphql_is_translatable_rweb_tweet_is_translatable_enabled: true,
  view_counts_everywhere_api_enabled: true,
  longform_notetweets_consumption_enabled: true,
  responsive_web_twitter_article_tweet_consumption_enabled: true,
  tweet_awards_web_tipping_enabled: false,
  longform_notetweets_rich_text_read_enabled: true,
  longform_notetweets_inline_media_enabled: true,
  rweb_video_timestamps_enabled: true,
  responsive_web_graphql_exclude_directive_enabled: true,
  verified_phone_label_enabled: false,
  freedom_of_speech_not_reach_fetch_enabled: true,
  standardized_nudges_misinfo: true,
  tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled: true,
  responsive_web_media_download_video_enabled: false,
  responsive_web_graphql_skip_user_profile_image_extensions_enabled: false,
  responsive_web_graphql_timeline_navigation_enabled: true,
  responsive_web_enhance_cards_enabled: false
}

class VideoCandidate {
  url: string = ''
  bitrate: number = 0
  width: number = 0
  height: number = 0
  thumbnail: string = ''
  durationSeconds: number = 0

  constructor(url: string, bitrate: number, width: number, height: number,
    thumbnail: string, durationSeconds: number) {
    this.url = url
    this.bitrate = bitrate
    this.width = width
    this.height = height
    this.thumbnail = thumbnail
    this.durationSeconds = durationSeconds
  }
}

// XProvider - X/Twitter provider
// GraphQL with login cookies can read protected tweets; syndication is the public fallback.
export class XProvider implements ProviderAdapter {
  canHandle(url: string): boolean {
    const lowerUrl = url.toLowerCase()
    return lowerUrl.includes('x.com') || lowerUrl.includes('twitter.com')
  }

  getProviderName(): string {
    return 'X'
  }

  async resolve(url: string, cookies?: string): Promise<ResolveResult | ProviderError> {
    const tweetId: string | null = this.extractTweetId(url)
    if (!tweetId) {
      return new ProviderError(ErrorCode.UNSUPPORTED, '无法从链接中提取推文 ID', false)
    }
    const sourceUrl: string = `https://x.com/i/status/${tweetId}`
    let graphqlError: ProviderError | null = null

    if (cookies && cookies.length > 0) {
      const gql: ResolveResult | ProviderError | null =
        await this.fetchViaGraphQL(tweetId, cookies, sourceUrl)
      if (gql instanceof ResolveResult) {
        return gql
      }
      if (gql instanceof ProviderError) {
        graphqlError = gql
      }
    }

    const syndication: ResolveResult | ProviderError | null =
      await this.fetchViaSyndication(tweetId, cookies, sourceUrl)
    if (syndication instanceof ResolveResult) {
      return syndication
    }
    if (syndication instanceof ProviderError) {
      return syndication
    }
    if (graphqlError) {
      return graphqlError
    }
    return new ProviderError(ErrorCode.PROVIDER_ERROR, 'X 解析失败：没有返回可用数据', true)
  }

  private async fetchViaGraphQL(tweetId: string, cookies: string,
    sourceUrl: string): Promise<ResolveResult | ProviderError | null> {
    const ct0: string = this.cookieValue(cookies, 'ct0')
    if (ct0.length === 0) {
      return new ProviderError(ErrorCode.LOGIN_REQUIRED,
        'X 登录 Cookie 缺少 ct0，请重新登录', false)
    }

    const variables: XGraphQLVariables = {
      tweetId: tweetId,
      withCommunity: false,
      includePromotedContent: false,
      withVoice: false
    }
    const apiUrl: string = `${X_GRAPHQL_API}/${X_TWEET_RESULT_QID}/TweetResultByRestId` +
      `?variables=${encodeURIComponent(JSON.stringify(variables))}` +
      `&features=${encodeURIComponent(JSON.stringify(X_FEATURES))}`

    const request = http.createHttp()
    try {
      const response = await request.request(apiUrl, {
        method: http.RequestMethod.GET,
        header: {
          'authorization': `Bearer ${X_BEARER}`,
          'x-csrf-token': ct0,
          'cookie': cookies,
          'x-twitter-auth-type': 'OAuth2Session',
          'x-twitter-active-user': 'yes',
          'x-twitter-client-language': 'en',
          'content-type': 'application/json',
          'user-agent': X_USER_AGENT,
          'accept': '*/*'
        },
        connectTimeout: 15000,
        readTimeout: 20000,
        maxLimit: 8 * 1024 * 1024
      })
      request.destroy()
      const body: string = response.result as string

      if (response.responseCode === 401 || response.responseCode === 403) {
        return new ProviderError(ErrorCode.LOGIN_REQUIRED,
          `X GraphQL 返回 HTTP ${response.responseCode}，登录 Cookie 可能已失效`, false)
      }
      if (response.responseCode !== 200) {
        return null
      }
      const data: Record<string, Object> = JSON.parse(body) as Record<string, Object>
      return this.parseTweetData(data, tweetId, sourceUrl, cookies, true)
    } catch (e) {
      try {
        request.destroy()
      } catch (ignore) {
      }
      return null
    }
  }

  private async fetchViaSyndication(tweetId: string, cookies: string | undefined,
    sourceUrl: string): Promise<ResolveResult | ProviderError | null> {
    const request = http.createHttp()
    try {
      const header: Record<string, string> = {
        'User-Agent': X_USER_AGENT,
        'Accept': 'application/json',
        'Referer': X_REFERER
      }
      if (cookies && cookies.length > 0) {
        header['Cookie'] = cookies
      }
      const response = await request.request(
        `${X_SYNDICATION_API}?id=${tweetId}&token=0&lang=en`, {
          method: http.RequestMethod.GET,
          header: header,
          connectTimeout: 15000,
          readTimeout: 20000,
          maxLimit: 8 * 1024 * 1024
        })
      request.destroy()

      if (response.responseCode === 404) {
        return new ProviderError(ErrorCode.LOGIN_REQUIRED,
          '该推文受保护或需要登录权限', false)
      }
      if (response.responseCode !== 200) {
        return new ProviderError(ErrorCode.PROVIDER_ERROR,
          `X 接口返回 HTTP ${response.responseCode}`, true)
      }
      const data: Record<string, Object> = JSON.parse(response.result as string) as Record<string, Object>
      return this.parseTweetData(data, tweetId, sourceUrl, cookies ?? '', false)
    } catch (e) {
      try {
        request.destroy()
      } catch (ignore) {
      }
      return new ProviderError(ErrorCode.PROVIDER_ERROR,
        `X 解析异常: ${(e as Error).message}`, true)
    }
  }

  // GraphQL and syndication share the same media structure recursively.
  private parseTweetData(data: Record<string, Object>, tweetId: string,
    sourceUrl: string, cookies: string, isGraphQL: boolean): ResolveResult | ProviderError {
    const tweet: Record<string, Object> | undefined = this.findTweetObject(data, isGraphQL)
    const root: Record<string, Object> = tweet ?? data

    const tombstone: string = this.findString(root, 'reason')
    if (isGraphQL && tombstone.length > 0) {
      return new ProviderError(ErrorCode.LOGIN_REQUIRED,
        `X 拒绝访问：${tombstone}`, false)
    }

    const title: string = this.extractText(root)
    const author: string = this.extractAuthor(root)
    const candidates: VideoCandidate[] = []
    const visited: Set<string> = new Set<string>()
    this.collectVideos(root, 0, candidates, visited, '')

    if (candidates.length === 0) {
      return new ProviderError(ErrorCode.NO_VIDEO,
        isGraphQL ? '该推文没有可下载的 MP4 视频（GraphQL 已登录）' : '该推文没有可下载的 MP4 视频', false)
    }

    candidates.sort((a: VideoCandidate, b: VideoCandidate): number => b.bitrate - a.bitrate)
    const formats: FormatOption[] = []
    const requestHeaders: Record<string, string> = {
      'Referer': sourceUrl,
      'User-Agent': X_USER_AGENT
    }
    if (cookies.length > 0) {
      requestHeaders['Cookie'] = cookies
    }

    for (let i = 0; i < candidates.length; i++) {
      const c: VideoCandidate = candidates[i]
      const label: string = c.height > 0 ? `X ${c.height}p` : `X 视频 ${i + 1}`
      formats.push(new FormatOption(
        `x_${c.height}p_${i}_mp4`,
        label,
        c.width,
        c.height,
        null,
        DownloadMode.DIRECT,
        c.url,
        requestHeaders
      ))
    }

    const first: VideoCandidate = candidates[0]
    return new ResolveResult(
      ProviderType.X,
      sourceUrl,
      title.length > 0 ? title : `X 推文 ${tweetId}`,
      author,
      first.thumbnail,
      first.durationSeconds,
      formats,
      WatermarkStatus.CONFIRMED_CLEAN,
      [],
      null
    )
  }

  // Recursively find video_info.variants (GraphQL / syndication).
  private collectVideos(node: Object, depth: number, out: VideoCandidate[],
    visited: Set<string>, inheritedThumb: string): void {
    if (depth > 12 || node === null || node === undefined) {
      return
    }
    if (Array.isArray(node)) {
      const arr: Object[] = node as Object[]
      for (const item of arr) {
        this.collectVideos(item, depth + 1, out, visited, inheritedThumb)
      }
      return
    }
    if (typeof node !== 'object') {
      return
    }

    const obj: Record<string, Object> = node as Record<string, Object>
    const thumb: string = ((obj['media_url_https'] as string) ?? '') ||
      ((obj['poster'] as string) ?? '') || inheritedThumb
    const original: Record<string, Object> | undefined = obj['original_info'] as Record<string, Object>
    const width: number = original ? ((original['width'] as number) ?? 0) : 0
    const height: number = original ? ((original['height'] as number) ?? 0) : 0

    const videoInfo: Record<string, Object> | undefined = obj['video_info'] as Record<string, Object>
    const variantsRaw: Object | undefined = videoInfo ?
      (videoInfo['variants'] as Object[]) : (obj['variants'] as Object[])
    if (variantsRaw) {
      const variants: Object[] = variantsRaw as Object[]
      let durationSeconds: number = 0
      if (videoInfo) {
        const durationMs: number = (videoInfo['duration_millis'] as number) ?? 0
        durationSeconds = Math.floor(durationMs / 1000)
      }
      for (const variantRaw of variants) {
        const variant: Record<string, Object> = variantRaw as Record<string, Object>
        const url: string = (variant['url'] as string) ?? ''
        const contentType: string = (variant['content_type'] as string) ?? ''
        const bitrate: number = (variant['bitrate'] as number) ?? 0
        if (url.length > 0 && (contentType === 'video/mp4' || url.includes('.mp4')) &&
          !visited.has(url)) {
          visited.add(url)
          out.push(new VideoCandidate(url, bitrate, width, height, thumb, durationSeconds))
        }
      }
    }

    for (const key of Object.keys(obj)) {
      const value: Object = obj[key]
      if (value !== null && value !== undefined && typeof value === 'object' &&
        key !== 'video_info' && key !== 'variants') {
        this.collectVideos(value, depth + 1, out, visited, thumb)
      }
    }
  }

  private findTweetObject(data: Record<string, Object>, isGraphQL: boolean):
    Record<string, Object> | undefined {
    if (!isGraphQL) {
      return data['tweet'] as Record<string, Object> ?? data
    }
    const dataObj: Record<string, Object> | undefined = data['data'] as Record<string, Object>
    if (!dataObj) {
      return undefined
    }
    const tweetResult: Record<string, Object> | undefined =
      dataObj['tweetResult'] as Record<string, Object>
    if (!tweetResult) {
      return undefined
    }
    const result: Record<string, Object> | undefined =
      tweetResult['result'] as Record<string, Object>
    if (!result) {
      return undefined
    }
    if (result['tweet']) {
      return result['tweet'] as Record<string, Object>
    }
    return result
  }

  private extractText(tweet: Record<string, Object>): string {
    let text: string = (tweet['full_text'] as string) ?? (tweet['text'] as string) ?? ''
    if (text.length === 0) {
      const note: Record<string, Object> | undefined = tweet['note_tweet'] as Record<string, Object>
      if (note) {
        const results: Record<string, Object> | undefined =
          note['note_tweet_results'] as Record<string, Object>
        const result: Record<string, Object> | undefined = results ?
          (results['result'] as Record<string, Object>) : undefined
        text = result ? ((result['text'] as string) ?? '') : ''
      }
    }
    if (text.length === 0) {
      text = this.findString(tweet, 'full_text')
    }
    if (text.length === 0) {
      text = this.findString(tweet, 'text')
    }
    return text.replace(/\s+/g, ' ').trim()
  }

  private extractAuthor(tweet: Record<string, Object>): string {
    const user: Record<string, Object> | undefined = tweet['user'] as Record<string, Object>
    if (user) {
      return (user['screen_name'] as string) ?? (user['name'] as string) ?? ''
    }
    const core: Record<string, Object> | undefined = tweet['core'] as Record<string, Object>
    if (core) {
      const userResults: Record<string, Object> | undefined =
        core['user_results'] as Record<string, Object>
      const userResult: Record<string, Object> | undefined = userResults ?
        (userResults['result'] as Record<string, Object>) : undefined
      const legacy: Record<string, Object> | undefined = userResult ?
        (userResult['legacy'] as Record<string, Object>) : undefined
      if (legacy) {
        return (legacy['screen_name'] as string) ?? (legacy['name'] as string) ?? ''
      }
    }
    return ''
  }

  private findString(node: Object, key: string): string {
    if (!node || typeof node !== 'object') {
      return ''
    }
    if (Array.isArray(node)) {
      for (const item of node as Object[]) {
        const found: string = this.findString(item, key)
        if (found.length > 0) {
          return found
        }
      }
      return ''
    }
    const obj: Record<string, Object> = node as Record<string, Object>
    const direct: Object = obj[key]
    if (typeof direct === 'string') {
      return direct as string
    }
    for (const k of Object.keys(obj)) {
      const value: Object = obj[k]
      if (value !== null && value !== undefined && typeof value === 'object') {
        const found: string = this.findString(value, key)
        if (found.length > 0) {
          return found
        }
      }
    }
    return ''
  }

  private cookieValue(cookies: string, name: string): string {
    for (const part of cookies.split(';')) {
      const segment: string = part.trim()
      const eq: number = segment.indexOf('=')
      if (eq > 0 && segment.substring(0, eq).trim() === name) {
        return segment.substring(eq + 1)
      }
    }
    return ''
  }

  private extractTweetId(url: string): string | null {
    const marker: string = '/status/'
    const idx: number = url.indexOf(marker)
    if (idx === -1) {
      return null
    }
    const start: number = idx + marker.length
    let end: number = start
    while (end < url.length && url.charCodeAt(end) >= 48 && url.charCodeAt(end) <= 57) {
      end++
    }
    return end > start ? url.substring(start, end) : null
  }
}
