import { PactV3, MatchersV3 } from '@pact-foundation/pact'
import path from 'path'

const { like, string } = MatchersV3

const provider = new PactV3({
  consumer: 'trilho-web',
  provider: 'trilho-backend',
  dir: path.resolve(process.cwd(), '../pacts'),
})

describe('POST /api/auth/firebase', () => {
  it('returns 400 for empty idToken', async () => {
    await provider
      .given('no state')
      .uponReceiving('a firebase auth request with empty token')
      .withRequest({
        method: 'POST',
        path: '/api/auth/firebase',
        headers: { 'Content-Type': 'application/json' },
        body: { idToken: '' },
      })
      .willRespondWith({ status: 400 })
      .executeTest(async (mockServer) => {
        const res = await fetch(`${mockServer.url}/api/auth/firebase`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ idToken: '' }),
        })
        expect(res.status).toBe(400)
      })
  })
})
