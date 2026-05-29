# Recording Studio Embeddable

`recording_studio_embeddable` is a v0.1 Rails isolated engine that adds secure, opt-in public iframe embeds to Recording Studio recordings.

## Install

```ruby
gem "recording_studio_embeddable"
```

```bash
bin/rails generate recording_studio_embeddable:install
bin/rails db:migrate
```

The installer mounts the engine at `/recording_studio_embeddable`, creates `config/initializers/recording_studio_embeddable.rb`, and copies the UUID migrations.

## Opting in

Embeds are off by default. Opt in per recordable class:

```ruby
class Page < ApplicationRecord
  recording_studio_embeddable renderer: "pages/embed", require_publishable: true
end
```

The Recording Studio capability form is also available:

```ruby
RecordingStudio::Capabilities::Embeddable.to(renderer: "pages/embed")
```

Recording methods added to `RecordingStudio::Recording` include `embed`, `current_embed`, `embed_child_recording`, `ensure_embed!`, `embeddable?`, `embed_enabled?`, `embed_public_path`, `embed_public_url`, `embed_code`, `update_embed!`, `disable_embed!`, and `enable_embed!`.

## Rendering and publishability

Public embeds render at `/recording_studio_embeddable/embeds/:token` in a dedicated iframe layout without host app chrome. Renderer precedence is:

1. capability options,
2. `recording_studio_embeddable` macro options,
3. global `renderer_resolver`,
4. class-name convention,
5. safe fallback.

The engine intentionally does **not** use a Publishable renderer by default. Publishable state is not duplicated; when `require_publishable` is true, public rendering uses parent recording Publishable helpers such as `currently_published?`, `current_publishable`, or `publishable_child_recording`. If helpers are unavailable, rendering fails closed.

## Security, domains, and rate limiting

Configure global allowed/blocked domains, and optionally override per capability or per embed. Requests that fail token lookup, disabled embeds, and unpublished content return 404; confirmed disallowed domains return 403; rate-limit failures return 429. Successful public responses set iframe-focused security headers including `Content-Security-Policy: frame-ancestors ...`.

Rate limiter adapters are `:null`, `:rails_cache`, and `:redis` (when a Redis-like object is configured). Adapter errors fail open by default; set `rate_limit_fail_closed = true` to fail closed.

## Caching and logging

Successful public responses use configurable public cache-control plus ETag/Last-Modified handling and support 304 responses. Failure responses are `no-store`.

Public views are logged to `RecordingStudioEmbeddable::View` only, never as Recording Studio events. The capture pipeline normalizes payloads, detects common bots, stores privacy-safe HMAC digests for IP/user-agent data, and can run asynchronously through `LogViewJob`. `PruneViewsJob` removes old rows.

## Dummy app

The dummy app mounts Recording Studio and this engine, opts `Page` into embeddable rendering, and includes a small `pages/embed` surface for manual validation.
