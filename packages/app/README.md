## Local domain (`ekowork.local`)

The Ekowork web app can be reached at `http://ekowork.local:<port>` (the harness runs
the dev server on `:4444`). This is a one-time, manual setup because it edits `/etc/hosts`
and therefore needs `sudo`:

```bash
sudo ./script/setup-local-domain.sh
```

The script appends `127.0.0.1 ekowork.local` and `::1 ekowork.local` to `/etc/hosts`
(idempotent — safe to re-run). Once added, open `http://ekowork.local:4444` in your
browser. Vite already accepts the `ekowork.local` Host header (`allowedHosts: true` in
`vite.config.ts`), so no server config change is needed.

Bare `http://ekowork.local` (port 80) needs a reverse proxy or a privileged port and is
out of scope for local dev — use the explicit `:<port>` form.

## Usage

Dependencies for these templates are managed with [pnpm](https://pnpm.io) using `pnpm up -Lri`.

This is the reason you see a `pnpm-lock.yaml`. That said, any package manager will work. This file can safely be removed once you clone a template.

```bash
$ npm install # or pnpm install or yarn install
```

### Learn more on the [Solid Website](https://solidjs.com) and come chat with us on our [Discord](https://discord.com/invite/solidjs)

## Available Scripts

In the project directory, you can run:

### `npm run dev` or `npm start`

Runs the app in the development mode.<br>
Open [http://localhost:3000](http://localhost:3000) to view it in the browser.

The page will reload if you make edits.<br>

### `npm run build`

Builds the app for production to the `dist` folder.<br>
It correctly bundles Solid in production mode and optimizes the build for the best performance.

The build is minified and the filenames include the hashes.<br>
Your app is ready to be deployed!

## E2E Testing

Playwright starts the Vite dev server automatically via `webServer`, and UI tests expect an opencode backend at `localhost:4096` by default.

```bash
bunx playwright install chromium
bun run test:e2e:local
bun run test:e2e:local -- --grep "settings"
```

Environment options:

- `PLAYWRIGHT_SERVER_HOST` / `PLAYWRIGHT_SERVER_PORT` (backend address, default: `localhost:4096`)
- `PLAYWRIGHT_PORT` (Vite dev server port, default: `3000`)
- `PLAYWRIGHT_BASE_URL` (override base URL, default: `http://localhost:<PLAYWRIGHT_PORT>`)

## Deployment

You can deploy the `dist` folder to any static host provider (netlify, surge, now, etc.)
