import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  vus: 100,
  duration: '10m',
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.005'],
  },
}

const BEARER = __ENV.STAGING_JWT ?? 'test-jwt'

export default function () {
  const res = http.get('https://staging.trilho.app/api/proxy/stations', {
    headers: { Cookie: `trilho_session=${BEARER}` },
  })
  check(res, { 'status 200': (r) => r.status === 200 })
  sleep(30)
}
