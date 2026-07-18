import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  vus: 50,
  duration: '3m',
  thresholds: {
    http_req_duration: ['p(95)<800'],
    http_req_failed: ['rate<0.005'],
  },
}

export default function () {
  const payload = JSON.stringify({ idToken: 'staging-test-token' })
  const res = http.post('https://staging.trilho.app/api/auth/firebase', payload, {
    headers: { 'Content-Type': 'application/json' },
  })
  check(res, { 'status 200 or 401': (r) => r.status === 200 || r.status === 401 })
  sleep(1)
}
