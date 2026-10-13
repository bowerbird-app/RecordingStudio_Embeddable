# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Builds the popup URL from the capability's controller/action and the
    # embed token. The absolute URL is request-time only and is never stored.
    class PopupUrl
      def self.call(recording:, token:, request:)
        capability = Capability.for(recording)
        return if capability.controller.blank? || capability.action.blank?

        path = route_path(capability.controller, capability.action, token)
        return if path.blank?

        "#{request.base_url}#{path}"
      end

      def self.route_path(controller, action, token)
        Rails.application.routes.url_helpers.url_for(
          controller: controller,
          action: action,
          token: token,
          only_path: true
        )
      rescue ActionController::UrlGenerationError, NoMethodError
        nil
      end
    end
  end
end
