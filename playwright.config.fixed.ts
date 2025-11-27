import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';
import { fileURLToPath } from 'url';

// ES module equivalent of __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const localEnv = path.resolve(process.cwd(), '.env');
const rootEnv  = path.resolve(__dirname, '../.env');
dotenv.config({ path: fs.existsSync(localEnv) ? localEnv : rootEnv });

export default defineConfig({
  testDir: './test',
  timeout: 280_000,
  expect: { timeout: 30_000 },
  reporter: [['html', { open: 'never' }], ['list'], ['line']],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    headless: false,
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
    launchOptions: {
      args: ['--disable-dev-shm-usage', '--disable-gpu'],
      slowMo: 250,
    },
    viewport: { width: 1280, height: 800 },
  },
  preserveOutput: 'always',
  projects: [{ name: 'chromium-metamask', use: { ...devices['Desktop Chrome'] } }],
});
