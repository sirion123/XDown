import { describe, it, expect } from '@ohos/hypium'
import { LinkNormalizer } from '../../main/ets/services/LinkNormalizer'
import { ProviderType } from '../../main/ets/models/ResolveResult'

export default function linkNormalizerTest(): void {
  describe('LinkNormalizer', () => {
    it('isValidUrl returns true for valid https URL', 0, () => {
      expect(LinkNormalizer.isValidUrl('https://x.com/user/status/123')).assertTrue()
    })

    it('isValidUrl returns true for valid http URL', 0, () => {
      expect(LinkNormalizer.isValidUrl('http://x.com/user/status/123')).assertTrue()
    })

    it('isValidUrl returns false for empty string', 0, () => {
      expect(LinkNormalizer.isValidUrl('')).assertFalse()
    })

    it('isValidUrl returns false for non-URL string', 0, () => {
      expect(LinkNormalizer.isValidUrl('not a url')).assertFalse()
    })

    it('isValidUrl returns false for ftp URL', 0, () => {
      expect(LinkNormalizer.isValidUrl('ftp://example.com')).assertFalse()
    })

    it('identifyPlatform returns X for x.com', 0, () => {
      expect(LinkNormalizer.identifyPlatform('https://x.com/user/status/123')).assertEqual(ProviderType.X)
    })

    it('identifyPlatform returns X for twitter.com', 0, () => {
      expect(LinkNormalizer.identifyPlatform('https://twitter.com/user/status/123')).assertEqual(ProviderType.X)
    })

    it('identifyPlatform returns UNKNOWN for unsupported platform', 0, () => {
      expect(LinkNormalizer.identifyPlatform('https://www.youtube.com/watch?v=123')).assertEqual(ProviderType.UNKNOWN)
    })
  })
}
