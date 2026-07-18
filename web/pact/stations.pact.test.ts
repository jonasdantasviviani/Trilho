import { PactV3, MatchersV3 } from '@pact-foundation/pact'
import path from 'path'

const { eachLike, like, decimal } = MatchersV3

const provider = new PactV3({
  consumer: 'trilho-web',
  provider: 'trilho-backend',
  dir: path.resolve(process.cwd(), '../pacts'),
})

describe('GET /api/stations', () => {
  it('returns empty array when no stations exist', async () => {
    await provider
      .given('no stations')
      .uponReceiving('a GET stations request')
      .withRequest({ method: 'GET', path: '/api/stations' })
      .willRespondWith({ status: 200, body: [] })
      .executeTest(async (mockServer) => {
        const res = await fetch(`${mockServer.url}/api/stations`)
        expect(res.status).toBe(200)
        const data = await res.json()
        expect(Array.isArray(data)).toBe(true)
      })
  })
})
