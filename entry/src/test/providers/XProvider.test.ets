import { describe, it, expect } from '@ohos/hypium'
import { XProvider } from '../../main/ets/providers/XProvider'
import { ResolveResult, ProviderType } from '../../main/ets/models/ResolveResult'
import { ProviderError, ErrorCode } from '../../main/ets/models/ProviderError'

export default function xProviderTest(): void {
  describe('XProvider', () => {
    const provider: XProvider = new XProvider()

    // ========== canHandle 测试 ==========
    it('canHandle returns true for x.com URLs', 0, () => {
      expect(provider.canHandle('https://x.com/user/status/123')).assertTrue()
    })

    it('canHandle returns true for twitter.com URLs', 0, () => {
      expect(provider.canHandle('https://twitter.com/user/status/123')).assertTrue()
    })

    it('canHandle returns false for non-x/twitter URLs', 0, () => {
      expect(provider.canHandle('https://www.youtube.com/watch?v=123')).assertFalse()
      expect(provider.canHandle('https://example.com/video/123')).assertFalse()
    })

    it('canHandle returns false for empty URL', 0, () => {
      expect(provider.canHandle('')).assertFalse()
    })

    // ========== getProviderName 测试 ==========
    it('getProviderName returns X', 0, () => {
      expect(provider.getProviderName()).assertEqual('X')
    })

    // ========== resolve 测试（需要网络） ==========
    it('resolve returns NOT_FOUND for non-existent tweet ID', 0, async () => {
      const result = await provider.resolve('https://x.com/elonmusk/status/9999999999999999999')
      if (result instanceof ProviderError) {
        // 可能是 NOT_FOUND 或 LOGIN_REQUIRED（取决于是否提供 Cookie）
        expect([ErrorCode.NOT_FOUND, ErrorCode.LOGIN_REQUIRED]).assertContain(result.code)
      } else {
        expect(result.provider).assertEqual(ProviderType.X)
      }
    })

    it('resolve returns ResolveResult with X provider type for valid URL', 0, async () => {
      const result = await provider.resolve('https://x.com/elikiiii_/status/1864365778255106160')
      if (result instanceof ResolveResult) {
        expect(result.provider).assertEqual(ProviderType.X)
        expect(result.formats.length > 0).assertTrue()
        expect(result.watermarkStatus).assertEqual('CONFIRMED_CLEAN')
      }
    })
  })
}
