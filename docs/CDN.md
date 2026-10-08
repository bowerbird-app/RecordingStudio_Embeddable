# CDN publish — RecordingStudio Artifacts (Cloudflare R2)

Partner iframe traffic should hit a stable Artifacts public URL, not App Platform
Rails. Embeddable pre-renders the iframe HTML and calls the Artifacts service API.
**Artifacts owns R2 upload, object keys, and public URL shape.** Embeddable does
not talk to DigitalOcean Spaces.

Pretty host paths (Cloudflare Worker) are a separate follow-up.

## URL strategy

Set `config.embed_url_strategy = :cdn` (or per-embed `embed_url_strategy = "cdn"`).

| Helper | Dedicated (default) | CDN (Artifacts) |
|--------|---------------------|-----------------|
| `embed_public_path` | `/recording_studio_embeddable/embeds/:token` | `/recording_studio_artifacts/{uuid}` |
| `embed_public_url` | host + dedicated path | Artifacts `public_url` |
| `embed_code` | iframe at dedicated URL | iframe at Artifacts URL only |

CDN helpers **never** paste the Rails mount into partner markup. The public URL
comes from `RecordingStudioArtifacts.publish` / `.update` →
`result.value[:public_url]` (also stored on the embed as
`metadata.artifact.public_url`).

Until the first publish succeeds you can set
`config.cdn_withhold_snippet_until_published = true` so `embed_code` stays empty
until `metadata.artifact.published_at` is set.

Default public URL shape (host-owned DNS):

```text
https://{subdomain}.{domain}/recording_studio_artifacts/{artifact_uuid}
```

Content updates call `.update` so the UUID and URL never change.

## Install Artifacts (host)

```bash
gem "recording_studio_artifacts", "~> 0.4.0",
    github: "bowerbird-app/RecordingStudio_artifacts", tag: "v0.4.0"

bundle install
bin/rails generate recording_studio_artifacts:install
bin/rails generate recording_studio_artifacts:migrations
bin/rails db:migrate
```

### Host credentials (production)

**Real R2 / CDN values stay host-owned.** Embeddable and Artifacts do not ship
production secrets. Set either:

1. **ENV** — preferred for App Platform / CI:
   - `ARTIFACT_CDN_SUBDOMAIN`, `ARTIFACT_CDN_DOMAIN`, `ARTIFACT_CDN_PATH_PREFIX`
   - `ARTIFACT_CDN_PUBLIC_BASE_URL` (optional full-base override)
   - `ARTIFACT_CDN_R2_ACCOUNT_ID`, `ARTIFACT_CDN_R2_ACCESS_KEY_ID`,
     `ARTIFACT_CDN_R2_SECRET_ACCESS_KEY`, `ARTIFACT_CDN_R2_BUCKET`,
     `ARTIFACT_CDN_R2_ENDPOINT`, `ARTIFACT_CDN_R2_REGION`
   - `ARTIFACT_CDN_CLOUDFLARE_ZONE_ID`, `ARTIFACT_CDN_CLOUDFLARE_API_TOKEN`
2. **Host Rails credentials** under `recording_studio_artifacts.cdn` (same key
   names as above, without the `ARTIFACT_CDN_` prefix).

`aws-sdk-s3` is a runtime dependency of Artifacts `0.4.0+` (hosts no longer add
it only for this gem). Full resolve order and DNS notes:
[RecordingStudio_artifacts docs/CDN.md](https://github.com/bowerbird-app/RecordingStudio_artifacts/blob/main/docs/CDN.md).

### Dummy credentials (this gem only)

The shared dummy file `test/dummy/config/credentials.yml.enc` (same
RecordingStudio_* development master key as sibling gems) includes a
`recording_studio_artifacts.cdn` key shape with safe placeholders
(`dev_placeholder`, `https://artifacts.example.test`). That blob is for
**dummy development only** — it is not production R2.

Dummy / test apps keep Artifacts `MemoryStorage` plus a fake
`cdn_public_base_url` so publish works without real R2:

```ruby
storage = RecordingStudioArtifacts::Cdn::MemoryStorage.new
RecordingStudioArtifacts.configure do |config|
  config.cdn_public_base_url = "https://artifacts.example.test"
  config.cdn_storage = storage
  config.cdn_purger = storage
end
```

## Publish triggers

`PublishEmbedToCdnJob` runs when:

- An embed with CDN strategy is created or updated (settings, domains, styling, enable/disable)
- The host calls `recording.enqueue_embed_cdn_publish!` after parent recording / theme / publishable changes

The job calls `Services::PublishEmbedToCdn`, which:

1. Renders the full iframe document (`RenderEmbedDocument`) and bakes
   `DomainPolicy#frame_ancestors` into an HTML CSP meta marker
2. Calls `RecordingStudioArtifacts.publish` (first time) or `.update` (re-publish)
   with `synchronous: true`
3. Stores `metadata.artifact` (`id`, `public_url`, `published_at`, …)

Disabled or publishable-blocked embeds overwrite the same artifact with a
minimal “unavailable” document (`frame-ancestors 'none'`). Embeddable does not
destroy embeds and does not call `RecordingStudioArtifacts.unpublish` — disable
keeps the stable Artifacts URL. Hosts that need to remove the R2 object can call
`RecordingStudioArtifacts.unpublish(id:)` themselves and clear `metadata.artifact`.

Artifacts `0.4.0+` marks an artifact `published` once R2 upload succeeds; purge
failures are recorded on `purge_error` / `purged_at` and no longer fail the
publish. `PublishArtifactJob` takes `(artifact_id, revision)` (Artifacts owns
that job; Embeddable does not enqueue it).

## Domain / frame-ancestors

Static HTML cannot vary CSP by `Referer`. At publish time Embeddable injects a
CSP comment + `<meta http-equiv="Content-Security-Policy">` into the HTML and
stores `frame_ancestors` on the Artifacts metadata. Hosts that need a real CSP
**response header** should promote it with a Cloudflare Transform Rule or Worker
(pretty-URL Worker is still deferred).

## CaptureView / rate limit

CDN-served hits never reach `EmbedsController`, so `CaptureView` and the Rails
rate limiter do not run on the edge. Use Cloudflare rate limiting / analytics for
CDN traffic. Keep `EmbedsController` as an optional origin fallback during
migration. Browser-payload / API embeds stay on Rails.

## What was retired

PR #10’s DigitalOcean Spaces path (`EMBED_CDN_SPACES_*`, `Cdn::SpacesClient`,
Spaces MemoryStorage as Embeddable’s upload target) is **not** the source of
truth. Do not reintroduce Spaces upload in this gem. Artifacts → R2 is the
publish path.
