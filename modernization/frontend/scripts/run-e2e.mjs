import { spawnSync } from 'node:child_process'
import { delimiter, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const frontendDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const nodeModulesDir = resolve(frontendDir, 'node_modules')
const playwrightCli = resolve(nodeModulesDir, 'playwright', 'cli.js')
const runId = process.env.E2E_RUN_ID || timestamp()

const env = {
  ...process.env,
  E2E_RUN_ID: runId,
  NODE_PATH: [nodeModulesDir, process.env.NODE_PATH].filter(Boolean).join(delimiter)
}

console.log(`E2E run: ${runId}`)
console.log(`E2E reports: ${resolve(frontendDir, '..', 'e2e', 'reports', 'runs', runId)}`)

const result = spawnSync(
  process.execPath,
  [playwrightCli, 'test', '--config', resolve(frontendDir, '..', 'e2e', 'playwright.config.js'), ...process.argv.slice(2)],
  {
    cwd: frontendDir,
    env,
    stdio: 'inherit'
  }
)

if (result.error) {
  console.error(result.error.message)
}

process.exit(result.status ?? 1)

function timestamp() {
  const now = new Date()
  const pad = (value) => String(value).padStart(2, '0')

  return [
    now.getFullYear(),
    pad(now.getMonth() + 1),
    pad(now.getDate()),
    '-',
    pad(now.getHours()),
    pad(now.getMinutes()),
    pad(now.getSeconds())
  ].join('')
}
