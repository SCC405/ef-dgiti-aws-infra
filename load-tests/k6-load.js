// Prueba de carga con k6 contra el Application Load Balancer.
//
// Uso:
//   k6 run -e BASE_URL=http://<alb_dns_name> load-tests/k6-load.js
//
// Escenario (unos 6 minutos): sube de 0 a 150 usuarios virtuales por escalones
// para ver cómo responden el ALB, la CPU de las EC2 y el Auto Scaling.
// Mezcla de tráfico:
//   70 % /api/stress  -> trabajo de CPU (lo que satura las instancias)
//   20 % /api/items   -> lectura desde la réplica de RDS
//   10 % /status      -> qué instancia respondió
//
// El reparto entre instancias se ve con load-tests/balance-check.ps1 y en CloudWatch.

import http from 'k6/http';
import { check, sleep } from 'k6';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';
const STRESS_N = __ENV.STRESS_N || '15000';

export const options = {
  stages: [
    { duration: '30s', target: 20 },   // calentamiento
    { duration: '1m', target: 50 },    // carga normal
    { duration: '1m30s', target: 100 }, // carga alta
    { duration: '1m30s', target: 150 }, // saturación
    { duration: '1m', target: 150 },   // sostener
    { duration: '30s', target: 0 },    // bajada
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'],     // menos de 5 % de errores
    http_req_duration: ['p(95)<3000'],  // 95 % por debajo de 3 s
    checks: ['rate>0.95'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

export default function () {
  const r = Math.random();
  let res;

  if (r < 0.7) {
    res = http.get(`${BASE_URL}/api/stress?n=${STRESS_N}`, { tags: { endpoint: 'stress' } });
  } else if (r < 0.9) {
    res = http.get(`${BASE_URL}/api/items?limit=20`, { tags: { endpoint: 'items' } });
  } else {
    res = http.get(`${BASE_URL}/status`, { tags: { endpoint: 'status' } });
  }

  check(res, { 'status 200': (x) => x.status === 200 });
  sleep(0.5);
}

export function handleSummary(data) {
  const m = data.metrics;
  const fmt = (v) => (v === undefined ? '-' : v.toFixed(1));
  const lines = [
    '',
    '================ RESUMEN PRUEBA DE CARGA ================',
    `URL                         : ${BASE_URL}`,
    `Usuarios virtuales (máx)    : ${m.vus_max.values.max}`,
    `Solicitudes totales         : ${m.http_reqs.values.count}`,
    `Solicitudes por segundo     : ${fmt(m.http_reqs.values.rate)}`,
    `Tiempo de respuesta prom.   : ${fmt(m.http_req_duration.values.avg)} ms`,
    `Tiempo de respuesta p95     : ${fmt(m.http_req_duration.values['p(95)'])} ms`,
    `Tiempo de respuesta p99     : ${fmt(m.http_req_duration.values['p(99)'])} ms`,
    `Porcentaje de errores       : ${(m.http_req_failed.values.rate * 100).toFixed(2)} %`,
    '=========================================================',
    '',
  ].join('\n');

  return {
    stdout: textSummary(data, { indent: ' ', enableColors: true }) + lines,
    'load-tests/results/summary.json': JSON.stringify(data, null, 2),
    'load-tests/results/summary.txt': lines,
  };
}
