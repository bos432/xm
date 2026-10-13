import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'

const utilityPath = new URL('../src/utils/timeline.js', import.meta.url)
const utilityFile = fileURLToPath(utilityPath)
const source = await readFile(utilityPath, 'utf8')
const requiredAnnotations = [
  '@param {Array<{ status?: string } | null> | null | undefined} items',
  '@returns {number}'
]
const missingAnnotations = requiredAnnotations.filter((annotation) => !source.includes(annotation))

if (missingAnnotations.length > 0) {
  process.stderr.write(`Missing utility type annotations: ${missingAnnotations.join(', ')}\n`)
  process.exit(1)
}

const result = spawnSync(process.execPath, ['--check', utilityFile], { stdio: 'inherit' })
process.exit(result.status ?? 1)
