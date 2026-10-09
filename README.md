# RecordingStudio Embeddable

RecordingStudio Embeddable is the Rails engine for secure public embeds in Recording Studio. Hosts opt recordable models into embeddable pages, control which domains may embed them, and manage cache, rate limiting, styling, and view logging from one place.

Two delivery modes ship in this gem:

1. **Iframe mode** — tokenized public HTML document for `<iframe src="…">` (dedicated Rails mount, or CDN via Artifacts).
2. **Browser-payload mode** — sanitized HTML fragment plus configuration for the WordPress Plugin Demo SDK (schema version 1).

## What It Includes

- Public embed routes for tokenized iframe recordings.
- CDN publish through [`recording_studio_artifacts`](https://github.com/bowerbird-app/RecordingStudio_artifacts) (Cloudflare R2) when `config.artifacts_enabled` is true and `embed_url_strategy` is `:cdn`.
- `RenderPayload` / `BrowserPayload` for API and SDK consumers (fragment + theme/sizing, no document chrome).
- Soft `:embed` capability-action registration when `recording_studio_api` is present (no hard dependency).
- A management UI for previewing, editing, styling, and reviewing stats for embeds.
- Host-side configuration for access control, cache policy, rate limiting, and logging.
- A Rails generator that mounts the engine, installs an initializer, and copies migrations.
- Helper methods for generating embed URLs and iframe markup from a recordable model.

## Requirements

- Ruby 3.3 or newer.
- Rails 8.1 or newer.
- A host application that can mount the engine and run the supplied migrations.
- `recording_studio_artifacts` `~> 0.4.0` (always installed; usage gated by
  `config.artifacts_enabled`, default off).
- `recording_studio_attachable` `~> 0.9` for direct image URLs on rich embeds
  (`url_mode: :direct` + `direct_url_host`).

## Install

Add the gem to your host app's `Gemfile`, then run the install generator:

```ruby
gem "recording_studio_embeddable"
```

If you're developing against this repository directly, use a local path or git source instead.

```bash
bin/rails generate recording_studio_embeddable:install
bin/rails db:migrate
```

The install generator will:

- Mount `RecordingStudioEmbeddable::Engine` in your routes.
- Create `config/initializers/recording_studio_embeddable.rb`.
- Copy the engine migrations into your app.
- Optionally create `config/recording_studio_embeddable.yml`.

If you prefer to install pieces manually, the default mount path is `/recording_studio_embeddable`.

## Opt In a Model

Declare the embeddable capability on any model you want to expose publicly:

```ruby
class Article < ApplicationRecord
  recording_studio_embeddable renderer: "articles/embed"
end
```

Once the record is ready, create an embed and use the generated public URL or iframe helper:

```ruby
article.ensure_embed!
article.embed_public_url(host: "example.com")
article.embed_code(host: "example.com")
```

## Iframe mode

### Dedicated (default)

The public embed route is token-based and lives under the mounted engine path:

`/recording_studio_embeddable/embeds/:token`

That path returns a full HTML document (embed layout, FlatPack CSS, theme CSS variables). It applies domain policy, HTTP cache validators, rate limiting, and **counts as a public view** via `CaptureView` / `EmbeddableViewLog`.

### CDN (Artifacts)

`recording_studio_artifacts` is always installed. Default
`config.artifacts_enabled = false` keeps every partner URL on the Rails mount
and never enqueues publish/purge jobs. Turning the switch off later falls
existing CDN embeds back to host URLs without deleting R2 objects.

To enable CDN partner URLs: run the Artifacts install + migrations, set
`config.artifacts_enabled = true`, then `config.embed_url_strategy = :cdn`
(or per-embed).

Embeddable pre-renders the iframe document and calls:

```ruby
RecordingStudioArtifacts.publish(body: html, content_type: "text/html; charset=utf-8", ...)
# re-publish:
RecordingStudioArtifacts.update(id: artifact_id, body: html, content_type: "...")
```

`embed_public_url` / `embed_code` then return `result.value[:public_url]` (also stored
on `embed.metadata["artifact"]`). That URL looks like
`https://{subdomain}.{domain}/recording_studio_artifacts/{uuid}` — never the Rails mount.

Install and configure Artifacts first. **Hosts supply real CDN secrets** via
`ARTIFACT_CDN_*` ENV or host credentials under `recording_studio_artifacts.cdn`
(`aws-sdk-s3` comes with Artifacts `0.4.0+`). This gem does not ship production R2 keys.
Dummy uses Artifacts `MemoryStorage` and safe placeholders in the shared dummy
credentials file. Details: [`docs/CDN.md`](docs/CDN.md).

Hosts should call `recording.enqueue_embed_cdn_publish!` after parent content, theme,
or publishable changes that affect the rendered document.

### Rich embeds and Attachable direct images

The shared Flatpack embed body (`recording_studio_embeddable/embeds/rich_body`)
renders title, description, cover, and gallery. Image `src` / `srcset` values come
from Attachable direct URLs only:

```ruby
RecordingStudioAttachable.configure do |config|
  config.url_mode = :direct
  config.direct_url_host = "images.example.com"
  # optional: config.image_variants = { poster: { resize_to_limit: [1280, 720] } }
  # optional exact list: config.preprocessed_variants = %i[small med large poster]
end
```

Before CDN publish, Embeddable processes preprocessed variants synchronously and
refuses to upload HTML that still points at Rails / Active Storage delivery paths.
See [`docs/CDN.md`](docs/CDN.md).

## Browser-payload mode

For the WordPress Plugin Demo SDK (and other authenticated API callers), render a schema v1 payload without going through the public iframe controller:

```ruby
result = RecordingStudioEmbeddable::RenderPayload.call(
  recording: parent_recording,
  embed: parent_recording.embed
)
hash = result.value!.to_h
# {
#   "schema_version" => 1,
#   "html" => "<…fragment…>",
#   "configuration" => { "theme" => {...}, "sizing" => {...} },
#   "sdk" => { "minimum_version" => "0.3.0" }
# }
```

`html` is a fragment (`layout: false`), sanitized server-side (no `script` / `iframe` / `object` / `embed` / `link` / `meta`, no `on*` handlers, no `javascript:` URLs). `configuration.theme` is the allowlisted token map from `ResolveTheme`; `configuration.sizing` is the allowlisted sizing subset (`width`, `mode`, `max_width`, `min_height`, `height`).

When `recording_studio_api` is loaded, the engine soft-registers a member `:embed` action (`GET`, `required_role: :view`) whose handler returns the same `to_h` shape.

The dummy app mounts that public API at `/recording_studio_api` and allowlists `:embed` on Page. That is the HTTP proof for WordPress Plugin Demo clients. Named-API enablement for FlatPack hosts remains a later step.

Admin HTML under `/recording_studio_api/admin_api` needs a host
`current_root_recording` that is an `AdminRoot`. The dummy supplies that through
`recording_studio_root_switchable` (ControllerSupport), a seeded AdminRoot with
Accessible owner access, and a RootSwitchable default that prefers AdminRoot —
the same contract as the RecordingStudio_api dummy.

### View logging policy

Browser-payload and API embeds do **not** count as public iframe views. `CaptureView` stays on `EmbedsController` only. That avoids double-counting when the WordPress Plugin Demo SDK refreshes or previews a payload.

## Configuration

The default configuration is intentionally locked down. At a minimum, you will usually want to set allowed embedder domains and any app-specific management authorization.

Common settings include:

- `artifacts_enabled` (default `false`) — host-wide Artifacts/CDN switch
- `embed_url_strategy` (`:dedicated` / `:cdn`) — used when Artifacts is enabled
- `allowed_embedder_domains` and `blocked_embedder_domains`
- `require_domain_allowlist` and `allow_any_domain`
- `require_publishable` and `fallback_to_publishable_renderer`
- `rate_limiting_enabled`, `rate_limiter`, `rate_limit`, and `rate_limit_window`
- `cache_mode` and `cache_policy`
- `view_logging_enabled` and the related sampling/privacy flags
- `management_authorizer`

The initializer generator writes a working starting point at `config/initializers/recording_studio_embeddable.rb`.

## Management UI

The engine also ships management routes for embed editors and operators. From there you can:

- Edit embed settings.
- Preview the rendered embed.
- Adjust styling overrides.
- Review summary and stats views.

Studio/management screens use core `recording_studio/default_layout` via `RecordingStudio::UsesDefaultLayout`. Do not wrap them in a second application shell. Core still puts `data-theme` on `<body>`; this gem copies FlatPack `rounded` onto `<html>` through `app/views/recording_studio/_default_layout_head.html.erb`. Hosts that already provide that partial should keep it. The public iframe at `/recording_studio_embeddable/embeds/:token` stays on the chrome-free embed layout.

## Development

For local development in this repository:

```bash
bundle install
bundle exec rake test
bundle exec rake test:dummy
cd test/dummy && bin/dev
```

The dummy app under `test/dummy` is the quickest way to verify host-app integration while working on the engine. It pins Accessible `v0.11.1`, Publishable `v0.4.2`, Attachable `v0.7.1`, Admin `v2.0.4`, and Recording Studio API `v0.5.5` (held). It mounts the public API so GET `:embed` can be exercised over HTTP. Dummy grants access through Accessible's public services and shims `RecordingStudio::Access.roles` so API 0.5.5 can still authorize member actions against string roles.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key. The dummy blob includes `recording_studio_artifacts.cdn` placeholders (`dev_placeholder`, fake `public_base_url`) so the key shape is visible — **never real R2 secrets** (this repo is public).

### Running the dummy against real dev R2

Real local R2 values live in committed encrypted
`test/dummy/config/credentials/development.yml.enc` and
`test/dummy/config/credentials/test.yml.enc`, decrypted by gitignored
`development.key` / `test.key` (same shared RecordingStudio_* key across RS
repos — never commit keys). Key names match featured_in (`r2.*`) and Artifacts
(`recording_studio_artifacts.cdn.*`) plus
`recording_studio_attachable.direct_url_host` — see
`test/dummy/config/credentials/development.yml.example`.

```bash
cd test/dummy
# development.key present locally; *.yml.enc already committed
export RECORDING_STUDIO_ARTIFACTS_ENABLED=true
bin/rails db:seed
bin/dev
```

Without the env key / `RAILS_MASTER_KEY`, dummy fallbacks (`cdn.example.test`,
MemoryStorage) keep CI green — no CI secret required for `test.yml.enc`. Full
steps: [`test/dummy/README.md`](test/dummy/README.md).

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. If `RAILS_MASTER_KEY` is set, `install.sh` writes gitignored
`test/dummy/config/master.key` so dummy credentials decrypt. Fetch-skills
always runs last. `.cursor/start.sh` starts PostgreSQL on each boot. Rebuild
with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).

## License

MIT
