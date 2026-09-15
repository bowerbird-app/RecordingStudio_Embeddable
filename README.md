# RecordingStudio Embeddable

RecordingStudio Embeddable is the Rails engine for secure public embeds in Recording Studio. Hosts opt recordable models into embeddable pages, control which domains may embed them, and manage cache, rate limiting, styling, and view logging from one place.

Two delivery modes ship in this gem:

1. **Iframe mode** — tokenized public HTML document for `<iframe src="…">`.
2. **Browser-payload mode** — sanitized HTML fragment plus configuration for the WordPress Plugin Demo SDK (schema version 1).

## What It Includes

- Public embed routes for tokenized iframe recordings.
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

The public embed route is token-based and lives under the mounted engine path:

`/recording_studio_embeddable/embeds/:token`

That path returns a full HTML document (embed layout, FlatPack CSS, theme CSS variables). It applies domain policy, HTTP cache validators, rate limiting, and **counts as a public view** via `CaptureView` / `EmbeddableViewLog`.

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

### View logging policy

Browser-payload and API embeds do **not** count as public iframe views. `CaptureView` stays on `EmbedsController` only. That avoids double-counting when the WordPress Plugin Demo SDK refreshes or previews a payload.

## Configuration

The default configuration is intentionally locked down. At a minimum, you will usually want to set allowed embedder domains and any app-specific management authorization.

Common settings include:

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

The dummy app under `test/dummy` is the quickest way to verify host-app integration while working on the engine. It pins `recording_studio_api` v0.5.5 and mounts the public API so GET `:embed` can be exercised over HTTP.

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. Fetch-skills always runs last. `.cursor/start.sh` starts
PostgreSQL on each boot. Rebuild with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).

## License

MIT
