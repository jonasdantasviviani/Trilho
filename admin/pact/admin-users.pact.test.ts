import { PactV3, MatchersV3 } from '@pact-foundation/pact'
import path from 'path'

const { like, boolean, string } = MatchersV3

const provider = new PactV3({
  consumer: 'trilho-admin',
  provider: 'trilho-backend',
  dir: path.resolve(process.cwd(), '../pacts'),
})

describe('GET /api/admin/users', () => {
  it('returns 403 without X-Admin-Key', async () => {
    await provider
      .given('no state')
      .uponReceiving('a GET users request without API key')
      .withRequest({ method: 'GET', path: '/api/admin/users' })
      .willRespondWith({ status: 403 })
      .executeTest(async (mockServer) => {
        const res = await fetch(`${mockServer.url}/api/admin/users`)
        expect(res.status).toBe(403)
      })
  })
})
