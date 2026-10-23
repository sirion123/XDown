import { describe, it, expect } from '@ohos/hypium'
import testsuite from '../test/Ability.test'

export default function appTest(): void {
  describe('AppTest', () => {
    it('run all tests', 0, () => {
      testsuite()
      expect(true).assertTrue()
    })
  })
}
