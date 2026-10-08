RecordingStudioEmbeddable install complete.

Next steps:

1. Review config/initializers/recording_studio_embeddable.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_embeddable.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_embeddable:migrations`.
4. Apply the migrations with `bin/rails db:migrate`.
5. For CDN partner URLs: run the Artifacts install + migrations generators,
   set host-owned `ARTIFACT_CDN_*` (or Rails credentials under
   `recording_studio_artifacts.cdn`), then set `config.artifacts_enabled = true`
   and `config.embed_url_strategy = :cdn`. See docs/CDN.md.
   Embeddable does not ship production R2 secrets. Leave `artifacts_enabled`
   false to serve embeds only from the Rails mount (Artifacts stays installed).
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
