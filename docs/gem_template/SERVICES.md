# Services

`RenderPayload`, `RenderEmbedDocument`, `EnsureEmbedImageVariants`, and `PublishEmbedToCdn` inherit `RecordingStudio::Services::BaseService`.

Call a service with `.call`. The return value is `RecordingStudio::Services::BaseService::Result`.

- `success?` and `failure?` report the outcome.
- `value` is set when the call succeeds.
- `error` is a string when the call fails. `errors` is an array of extra detail.
- `value!` returns `value`, or raises `error`.
- `on_success` and `on_failure` yield and return the same result.

Register `before_service`, `after_service`, and `around_service` on `RecordingStudio.configuration.hooks`.
