import { defineConfig, devices } from '@playwright/test'

const runId = process.env.E2E_RUN_ID || new Date().toISOString().replace(/[-:T]/g, '').slice(0, 15)
const runDir = `./reports/runs/${runId}`

export default defineConfig({
  testDir: './tests',
  outputDir: `${runDir}/artifacts`,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [
    ['html', { outputFolder: `${runDir}/html`, open: 'never' }],
    ['json', { outputFile: `${runDir}/results.json` }],
    ['list']
  ],
  use: {
    baseURL: process.env.E2E_BASE_URL || 'https://nxm.zlck888.com',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } }
  ]
})
