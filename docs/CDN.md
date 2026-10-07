# CDN Strategy 1 — DigitalOcean Spaces + Cloudflare

Partner iframe traffic should hit a stable CDN URL, not App Platform Rails. The gem owns the publisher; the host owns Spaces / Cloudflare credentials and DNS.

## URL strategy

Set `config.embed_url_strategy = :cdn` (or per-embed `embed_url_strategy = "cdn"`).

| Helper | Dedicated (default) | CDN |
|--------|---------------------|-----|
| `embed_public_path` | `/recording_studio_embeddable/embeds/:token` | `/embeds/:token.html` |
| `embed_public_url` | host + dedicated path | `{cdn_public_base_url}/embeds/{token}.html` |
| `embed_code` | iframe pointing at dedicated URL | iframe pointing at CDN URL only |

CDN helpers **never** paste the Rails mount into partner markup. Until the first publish succeeds you can either:

1. Keep returning the same CDN hostname (default) and point Cloudflare origin fallback at `EmbedsController` during migration, or
2. Set `config.cdn_withhold_snippet_until_published = true` so `embed_code` stays empty until `metadata.cdn.published_at` is set.

Object keys are stable forever: `embeds/{token}.html`. Content updates **overwrite the same key** and purge Cloudflare.

## Host credentials / env vars

Resolve order: explicit `config.*` → ENV → `Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, ...)`.

| Purpose | ENV | Credentials dig | Config attr |
|---------|-----|-----------------|-------------|
| Public CDN hostname | `EMBED_CDN_PUBLIC_BASE_URL` | `:public_base_url` | `cdn_public_base_url` |
| Spaces endpoint | `EMBED_CDN_SPACES_ENDPOINT` | `:spaces_endpoint` | `cdn_spaces_endpoint` |
| Spaces region | `EMBED_CDN_SPACES_REGION` | `:spaces_region` | `cdn_spaces_region` |
| Spaces bucket | `EMBED_CDN_SPACES_BUCKET` | `:spaces_bucket` | `cdn_spaces_bucket` |
| Spaces key | `EMBED_CDN_SPACES_ACCESS_KEY_ID` | `:spaces_access_key_id` | `cdn_spaces_access_key_id` |
| Spaces secret | `EMBED_CDN_SPACES_SECRET_ACCESS_KEY` | `:spaces_secret_access_key` | `cdn_spaces_secret_access_key` |
| Cloudflare zone | `EMBED_CDN_CLOUDFLARE_ZONE_ID` | `:cloudflare_zone_id` | `cdn_cloudflare_zone_id` |
| Cloudflare token | `EMBED_CDN_CLOUDFLARE_API_TOKEN` | `:cloudflare_api_token` | `cdn_cloudflare_api_token` |

Example credentials YAML (edit with the shared dummy master key, or host production credentials):

```yaml
recording_studio_embeddable:
  cdn:
    public_base_url: https://embeds.example.com
    spaces_endpoint: https://nyc3.digitaloceanspaces.com
    spaces_region: nyc3
    spaces_bucket: embeds-prod
    spaces_access_key_id: REPLACE_ME
    spaces_secret_access_key: REPLACE_ME
    cloudflare_zone_id: REPLACE_ME
    cloudflare_api_token: REPLACE_ME
```

Dummy uses MemoryStorage in test/dev when Spaces credentials are placeholders. Production hosts should add `gem "aws-sdk-s3"` and real Spaces keys.

## Publish triggers

`PublishEmbedToCdnJob` runs when:

- An embed with CDN strategy is created or updated (settings, domains, styling, enable/disable)
- The host calls `recording.enqueue_embed_cdn_publish!` after parent recording / theme / publishable changes that affect the rendered document

Disabled or unpublished embeds overwrite the same key with a minimal “unavailable” document (`frame-ancestors 'none'`).

## Domain / frame-ancestors

Static HTML cannot vary CSP by `Referer`. At publish time the gem:

1. Builds `DomainPolicy#frame_ancestors` the same way as `PublicAccess` (baked allowlist, or `*` when `allow_any_domain` and the allowlist is empty)
2. Injects a CSP comment + `<meta http-equiv="Content-Security-Policy">` into the HTML
3. Stores `content-security-policy` on the Spaces object metadata
4. Re-publishes whenever domain settings change

Browsers enforce `frame-ancestors` only via an HTTP response header. Hosts should promote object metadata (or a fixed rule when every embed allows any domain) with a Cloudflare Transform Rule or Worker. Example Worker sketch:

```js
export default {
  async fetch(request, env) {
    const response = await fetch(request)
    const csp = response.headers.get("x-amz-meta-content-security-policy")
    if (!csp) return response
    const headers = new Headers(response.headers)
    headers.set("Content-Security-Policy", csp)
    return new Response(response.body, { status: response.status, headers })
  }
}
```

## CaptureView / rate limit

CDN-served hits never reach `EmbedsController`, so `CaptureView` and the Rails rate limiter do not run on the edge. Use Cloudflare rate limiting / analytics for CDN traffic. Keep `EmbedsController` as an optional origin fallback during migration (or document deprecation once all partners are on the CDN hostname). Browser-payload / API embeds stay on Rails and still skip `CaptureView`.

## Origin fallback

`GET /recording_studio_embeddable/embeds/:token` remains available. Point Cloudflare origin fallback there only during cutover. Partner snippets must keep using the CDN URL.
