import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn, spawnSync } from 'node:child_process'

const here = path.dirname(fileURLToPath(import.meta.url))
const runId = process.argv[2]
if (!runId || !/^[a-zA-Z0-9-]+$/.test(runId)) throw new Error('Provide a unique alphanumeric run ID')
const sandbox = path.join(here, 'reports', 'runs', runId, 'sandbox')
const dist = path.resolve(here, '../frontend/dist')
if (!fs.existsSync(path.join(dist, 'index.html'))) throw new Error('Build the frontend first')
fs.mkdirSync(sandbox, { recursive: true, mode: 0o700 })
const env = { ...process.env, NXM_QA_SANDBOX: sandbox }
const php = process.env.PHP_BIN || 'php'
const prepare = spawnSync(php, [path.join(here, 'prepare-isolated.php')], { env, encoding: 'utf8' })
if (prepare.status !== 0 || !fs.existsSync(path.join(sandbox, 'credentials.json'))) {
  process.stderr.write(prepare.stderr || prepare.stdout)
  process.exit(prepare.status || 1)
}
const ready = JSON.parse(prepare.stdout.trim())
if (ready.status !== 'ready' || ready.external_delivery !== false) throw new Error('Invalid isolated fixture result')
process.stdout.write(prepare.stdout)
const backend = spawn(php, ['-S', '127.0.0.1:18741', path.join(here, 'isolated-router.php')], { env, stdio: ['ignore', 'ignore', 'pipe'] })
backend.stderr.on('data', chunk => process.stderr.write(chunk))
backend.on('error', error => { process.stderr.write(String(error)); process.exitCode = 1; server.close() })
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.woff2': 'font/woff2' }
const server = http.createServer((req, res) => {
  if (req.url.startsWith('/api/')) {
    const proxy = http.request({ hostname: '127.0.0.1', port: 18741, path: req.url, method: req.method, headers: req.headers }, upstream => {
      res.writeHead(upstream.statusCode, upstream.headers)
      upstream.pipe(res)
    })
    proxy.on('error', () => { res.writeHead(502); res.end('Isolated backend unavailable') })
    req.pipe(proxy)
    return
  }
  const pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname)
  const candidate = path.resolve(dist, '.' + pathname)
  if (!candidate.startsWith(dist + path.sep) && candidate !== dist) { res.writeHead(403); res.end(); return }
  const file = fs.existsSync(candidate) && fs.statSync(candidate).isFile() ? candidate : path.join(dist, 'index.html')
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' })
  fs.createReadStream(file).pipe(res)
})
server.listen(18742, '127.0.0.1', () => console.log(`Isolated QA ready: http://127.0.0.1:18742 ; run=${runId}`))
server.on('error', error => { process.stderr.write(String(error)); backend.kill(); process.exitCode = 1 })
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => { backend.kill(); server.close(() => process.exit(0)) })
