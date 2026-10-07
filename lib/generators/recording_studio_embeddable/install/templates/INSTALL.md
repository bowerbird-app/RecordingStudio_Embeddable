RecordingStudioEmbeddable install complete.

Next steps:

1. Review config/initializers/recording_studio_embeddable.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_embeddable.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_embeddable:migrations`.
4. Apply the migrations with `bin/rails db:migrate`.
5. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
6. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
7. For CDN Strategy 1 (DigitalOcean Spaces + Cloudflare), set `embed_url_strategy = :cdn` and the `EMBED_CDN_*` env vars documented in docs/CDN.md. Add `gem "aws-sdk-s3"` when publishing for real.