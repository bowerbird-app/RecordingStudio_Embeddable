# frozen_string_literal: true

RecordingStudioApi.configure do |config|
  config.openapi_title = "WordPress Plugin Demo"
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_oauth_enabled = false
  config.api_management_authorization_required = false
end

# Host enablement only. The gem already registered :embed.
RecordingStudioApi.register_recordable_type_api(
  "Page",
  operations: %i[show],
  capability_actions: %i[embed],
  serializer: ->(page, **) { { title: page.title } },
  output_keys: %i[title]
)
