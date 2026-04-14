# SnooRb

Rails app for connecting to a Happiest Baby Snoo account, loading device and baby settings, and showing recent Snoo activity in a browser.

The app currently:

- authenticates against the Snoo APIs using stored Rails credentials or manual login
- fetches device metadata and baby/settings data from the observed API endpoints
- receives live updates through the app's listener path and stores normalized events in Postgres
- can send experimental runtime control commands for hold, adjacent level changes, and sticky white noise
- shows current device status, recent event history, raw payloads, and selected settings in the dashboard

## Requirements

- Ruby and Bundler
- Node.js and Yarn
- PostgreSQL

## Setup

1. Install dependencies:

```bash
bundle install
yarn install
```

2. Create and migrate the database:

```bash
bin/rails db:prepare
```

3. Add Snoo credentials to Rails credentials if you want one-click connect:

```yaml
snoo:
  username: your-email@example.com
  password: your-password
```

If these values are not present, the dashboard shows manual login fields instead.

## Running

Use the development Procfile:

```bash
bin/dev
```

The Rails server runs on `http://localhost:4000`.

## Notes

- Internal API shape notes are in docs/snoo_api_shapes.md.
- Event rows are deduplicated before insert and also protected by a database-level event signature.
- Runtime controls are sent over the device's AWS IoT MQTT control topic using a small Node helper, then the app refreshes the device snapshot to update the UI.
- The app is built around the API and event shapes observed during development; if Snoo changes those payloads, parsing may need to be updated.
