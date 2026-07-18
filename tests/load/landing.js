import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  vus: 200,
  duration: '5m',
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
}

export default function () {
  const res = http.get('https://staging.trilho.app/')
  check(res, { 'status 200': (r) => r.status === 200 })
  sleep(1)
}
