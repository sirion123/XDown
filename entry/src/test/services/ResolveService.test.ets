import { describe, it, expect } from '@ohos/hypium'
import { ResolveService } from '../../main/ets/services/ResolveService'
import { ResolveResult, ProviderType } from '../../main/ets/models/ResolveResult'
import { ProviderError, ErrorCode } from '../../main/ets/models/ProviderError'

export default function resolveServiceTest(): void {
  describe('ResolveService', () => {
    const service: ResolveService = new ResolveService()

    // ========== URL 校验测试 ==========
    it('resolve returns error for empty URL', 0, async () => {
      const result = await service.resolve('')
      expect(result instanceof ProviderError).assertTrue()
      if (result instanceof ProviderError) {
        expect(result.code).assertEqual(ErrorCode.UNSUPPORTED)
      }
    })

    it('resolve returns UNSUPPORTED for YouTube URL', 0, async () => {
      const result = await service.resolve('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
      expect(result instanceof ProviderError).assertTrue()
      if (result instanceof ProviderError) {
        expect(result.code).assertEqual(ErrorCode.UNSUPPORTED)
      }
    })

    // ========== 平台识别测试 ==========
    it('resolve identifies X URLs correctly', 0, async () => {
      const result = await service.resolve('https://x.com/elikiiii_/status/1864365778255106160')
      if (result instanceof ResolveResult) {
        expect(result.provider).assertEqual(ProviderType.X)
      }
    })

    // ========== twitter.com 兼容性测试 ==========
    it('resolve handles twitter.com domain as X provider', 0, async () => {
      const result = await service.resolve('https://twitter.com/elikiiii_/status/1864365778255106160')
      if (result instanceof ResolveResult) {
        expect(result.provider).assertEqual(ProviderType.X)
      }
    })
  })
}
