import { spawnSync } from 'node:child_process'
import { delimiter, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const frontendDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const nodeModulesDir = resolve(frontendDir, 'node_modules')
const playwrightBin = process.platform === 'win32'
  ? resolve(nodeModulesDir, '.bin', 'playwright.cmd')
  : resolve(nodeModulesDir, '.bin', 'playwright')

const env = {
  ...process.env,
  NODE_PATH: [nodeModulesDir, process.env.NODE_PATH].filter(Boolean).join(delimiter)
}

const result = spawnSync(
  playwrightBin,
  ['test', '--config', resolve(frontendDir, '..', 'e2e', 'playwright.config.js'), ...process.argv.slice(2)],
  {
    cwd: frontendDir,
    env,
    shell: process.platform === 'win32',
    stdio: 'inherit'
  }
)

if (result.error) {
  console.error(result.error.message)
}

process.exit(result.status ?? 1)
