import { describe, it, expect } from '@ohos/hypium'
import xProviderTest from './providers/XProvider.test'
import resolveServiceTest from './services/ResolveService.test'
import linkNormalizerTest from './services/LinkNormalizer.test'

export default function listTest(): void {
  describe('XDown', () => {
    it('test suite runs', 0, () => {
      expect(true).assertTrue()
    })
  })

  xProviderTest()
  resolveServiceTest()
  linkNormalizerTest()
}
