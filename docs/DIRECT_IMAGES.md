# Attachable direct images on embeds

Embeddable rich pages (management Preview and the public iframe document) render
cover + gallery images with **Attachable direct URLs** — never Rails engine
preview paths and never `/rails/active_storage/...`.

## Host setup

Pin Attachable `~> 0.13` (tag `v0.13.0`) and configure:

```ruby
RecordingStudioAttachable.configure do |config|
  config.url_mode = :direct
  config.direct_url_host = "images.example.com"
end
```

`DirectUrl` builds `https://<direct_url_host>/<blob key>` with no expiry. Opt
parent recordables into `RecordingStudio::Capabilities::Attachable`.

Default preprocessed variants are `small` / `med` / `large` plus any custom names
you add under `config.image_variants`. Set `preprocessed_variants` only when you
want an exact override.

## How embeds build `<img>` tags

`RecordingStudioEmbeddable::DirectImageUrls` (and `DirectImageHelper`) call:

- `attachment.original_url(mode: :direct)` for the base `src` when needed
- `attachment.url_for_variant(name, mode: :direct)` only when
  `attachment.variant_processed?(name)` is true
- Unprocessed names are **omitted** from `srcset` (no Rails fallback)

Each image includes `srcset` / `sizes`, explicit `width` / `height`, and
`loading="lazy"` except the cover (`loading="eager"`). Captions sit in a
padded `figcaption` below the media (Flatpack Carousel pattern) so
`overflow-hidden` on the image wrapper never clips the first glyph.

## Artifacts publish

`PublishEmbedToCdn` runs `EnsureEmbedImageVariants` first (sync
`PreprocessVariantsJob` + `variant_processed?` checks), then
`PublishedHtmlGuard` on the rendered HTML. Details in [`CDN.md`](CDN.md).

## Dummy

By default the dummy sets `direct_url_host = "cdn.example.test"` and serves blob
keys via `DummyCdnController` / `DummyCdnHost` so local screenshots show real
pictures without R2 credentials. That stand-in is dummy-only and only rewrites
the `cdn.example.test` host.

To point development at a real Attachable custom domain + R2 bucket, put values
in `config/credentials/development.yml.enc` under
`recording_studio_attachable.direct_url_host` and `r2.*` (gitignored
`development.key` — see [`test/dummy/README.md`](../test/dummy/README.md)).
Seeds attach a hero + gallery on every embeddable example (Page and Article).

Variant preprocessing (seeds and dummy integration tests) uses Active Storage’s
`:vips` processor — install **libvips** locally and in CI (`libvips42` /
`libvips42t64` on Ubuntu). Without it, `PreprocessVariantsJob` cannot materialize
variant blobs and direct `srcset` URLs stay empty.
