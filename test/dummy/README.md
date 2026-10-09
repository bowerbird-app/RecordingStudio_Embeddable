# Dummy App

This Rails app exists to validate the Recording Studio addon template in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables, with Accessible
  bootstrap (`bootstrap_owner_access!`) so publishable edit/preview work for admin
- Artifacts mount home at `/recording_studio_artifacts` renders Flatpack wiring
  docs (the engine itself only returns an empty `200`)
- FlatPack layout integration and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Public Recording Studio API at `/recording_studio_api` with GET `:embed` on Page for WordPress Plugin Demo clients
- A starter sidebar menu and companion docs pages for gem-specific onboarding

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Running the dummy against real dev R2

This repo is public. Committed credentials stay **dummy placeholders**
(`cdn.example.test`, `artifacts.example.test`, `dev_placeholder`). Never put real
R2 secrets in `credentials.yml.enc`, plaintext files that are tracked, PR bodies,
or chat.

Local development can load real values from ENV or a **gitignored** file:

1. From a `featured_in` checkout, inspect key names only (do not paste secret
   values into this repo):

   ```bash
   bin/rails credentials:show -e development
   ```

   Map these shapes (key names only):

   - Active Storage R2: `r2.access_key_id`, `r2.secret_access_key`, `r2.endpoint`,
     `r2.bucket` (and optional `r2.region`) — same keys as featured_in
     `config/storage.yml`
   - Attachable public host: `direct_url_host` → ENV `ATTACHABLE_DIRECT_URL_HOST`
   - Artifacts CDN: `ARTIFACT_CDN_*` / `recording_studio_artifacts.cdn` keys
     (`subdomain`, `domain`, `path_prefix`, `public_base_url`, `r2_*`,
     `cloudflare_*`) — see [`docs/CDN.md`](../../docs/CDN.md)

2. Copy a template and fill values **locally** (either file works):

   ```bash
   cd test/dummy
   cp config/local_r2.yml.example config/local_r2.yml
   # or:
   cp .env.development.local.example .env.development.local
   ```

   Both paths are gitignored. Templates list **key names only**.

3. Start the dummy with Artifacts usage on, reseed so Attachable uploads go to R2,
   then publish:

   ```bash
   cd test/dummy
   export RECORDING_STUDIO_ARTIFACTS_ENABLED=true
   bin/rails db:seed
   bin/dev
   ```

   Sign in as `admin@admin.com` / `Password`, open an embed’s management
   Settings, set URL strategy to CDN if needed, save (triggers publish), then
   open the Artifacts public URL.

When ENV / local files are unset, the dummy keeps MemoryStorage +
`cdn.example.test` / `artifacts.example.test` so CI is unchanged.

## Useful Routes

- `/` - embeddable dummy index with a table of page recordings and edit/preview actions
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/recording_studio_artifacts` - dummy Artifacts wiring page (toggle via `RECORDING_STUDIO_ARTIFACTS_ENABLED`)
- `/recording_studio_artifacts/:uuid` - dummy-only MemoryStorage/tmp stand-in for the CDN edge path (screenshot/publish checks)
- `/dummy_cdn/*key` - dummy-only stand-in for Attachable `direct_url_host` blob bytes
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - starter sidebar pages to adapt for the gem
- `/dummy/pages/new` - add-page form used to create embeddable test pages
- `/up` - Rails health check
- `POST /recording_studio_api/oauth/token` - OAuth2 `client_credentials` token for a provisioned API client
- `GET /recording_studio_api/api/v1/pages/:id/actions/embed` - AccessGrant-scoped BrowserPayload (schema version 1)
- `GET /recording_studio_api/api/v1/pages/:id/embed` - short alias for the same payload

## Why This App Exists

Use this app to verify the generated addon experience before renaming the gem or copying patterns into another host app. If a layout, route, asset source, or Recording Studio initializer change breaks here, the template likely needs adjustment before reuse.

Authenticated dummy pages use `RecordingStudio::UsesDefaultLayout` and `recording_studio/default_layout`. Core PageNav owns back/close. Dummy loads `flat_pack/application` and copies FlatPack `rounded` onto `<html>` via `app/views/recording_studio/_default_layout_head.html.erb`. Docs navigation lives in `app/views/application/_app_nav.html.erb` as in-page dummy docs links, not as the product frame.

Tailwind scans FlatPack and Recording Studio from Bundler’s loaded gem paths. `bin/rails tailwindcss:build` and `tailwindcss:watch` write `app/assets/tailwind/gem_sources.css` from `Gem.loaded_specs` and `Bundler.bundle_path` before compiling, so Switch and icon size utilities work under vendor, CI, mise, and local `BUNDLE_PATH`.

Likewise, the home page in `app/views/home/index.html.erb` should stay a minimal demo surface for the gem's core feature. Do not turn it into a wall of documentation; the dedicated docs pages exist so deeper explanations can live in focused sections.
