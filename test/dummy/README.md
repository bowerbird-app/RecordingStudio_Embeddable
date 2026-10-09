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
- RootSwitchable + seeded `AdminRoot` so API admin HTML
  (`/recording_studio_api/admin_api` and settings / rate_limiting / requests /
  errors / logs) can resolve `current_root_recording`
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

This repo is public. Shared `config/credentials.yml.enc` stays **dummy
placeholders** only. Real Cloudflare R2 values for local development / test live
in **per-environment** Rails credentials (same shared RecordingStudio_* key
across RS repos):

- Committed encrypted: `config/credentials/development.yml.enc`,
  `config/credentials/test.yml.enc`
- Gitignored keys: `config/credentials/development.key`,
  `config/credentials/test.key` (never commit; same shared key value)

Key names match featured_in + RecordingStudio Artifacts (see
`config/credentials/development.yml.example` — names only):

```yaml
secret_key_base:          # required — env credentials replace credentials.yml.enc
r2:                       # featured_in Active Storage
  access_key_id:
  secret_access_key:
  endpoint:
  bucket:
recording_studio_artifacts:
  cdn:                    # Artifacts Credentials dig path
    subdomain:
    domain:
    path_prefix:
    public_base_url:
    r2_account_id:
    r2_access_key_id:
    r2_secret_access_key:
    r2_bucket:
    r2_endpoint:
    r2_region:
    cloudflare_zone_id:
    cloudflare_api_token:
recording_studio_attachable:
  direct_url_host:        # Attachable DirectUrl host
```

### Steps (Marco / local)

1. From a `featured_in` checkout, inspect **key names only** (do not paste secret
   values into chat or this public repo):

   ```bash
   bin/rails credentials:show -e development
   ```

2. Put `config/credentials/development.key` locally (gitignored). For the test
   env, copy the same shared key to `config/credentials/test.key`. Decrypt /
   edit the committed env blobs under the key paths above
   (`bin/rails credentials:edit --environment development` from `test/dummy`).

3. Start the dummy with Artifacts usage on, reseed, publish:

   ```bash
   cd test/dummy
   export RECORDING_STUDIO_ARTIFACTS_ENABLED=true
   bin/rails db:seed
   bin/dev
   ```

   Sign in as `admin@admin.com` / `Password`, open an embed’s management
   Settings, set URL strategy to CDN if needed, save (triggers publish), then
   open the Artifacts public URL.

Without `development.key` / `test.key` (and without `RAILS_MASTER_KEY`), the
dummy keeps MemoryStorage + `cdn.example.test` / `artifacts.example.test` so CI
is unchanged — `config.require_master_key` is false in test, so an undecryptable
`test.yml.enc` does not raise. Artifacts’ built-in `ARTIFACT_CDN_*` ENV resolve
remains a harmless optional override.

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
