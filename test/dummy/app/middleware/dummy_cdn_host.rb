# frozen_string_literal: true

# When the request Host matches the dummy stand-in direct_url_host
# (cdn.example.test), rewrite the path to DummyCdnController so local screenshots
# and CI resolve blob bytes without real R2. Real ATTACHABLE_DIRECT_URL_HOST
# values are never rewritten — those requests go to the real CDN edge.
class DummyCdnHost
  DUMMY_STAND_IN_HOST = "cdn.example.test"

  def initialize(app)
    @app = app
  end

  def call(env)
    host = env["HTTP_HOST"].to_s.split(":").first
    if stand_in_host?(host) && !engine_path?(env["PATH_INFO"])
      env = env.dup
      env["PATH_INFO"] = "/dummy_cdn#{env["PATH_INFO"]}"
      env["SCRIPT_NAME"] = ""
      env["REQUEST_URI"] = env["PATH_INFO"]
    end
    @app.call(env)
  end

  private

  def stand_in_host?(host)
    return false if host.blank?

    direct_host = direct_url_host_name
    return false if direct_host.blank?
    return false unless direct_host == DUMMY_STAND_IN_HOST

    host == DUMMY_STAND_IN_HOST
  end

  def direct_url_host_name
    return unless defined?(RecordingStudioAttachable)

    host = RecordingStudioAttachable.configuration.direct_url_host.to_s
    return if host.blank?

    RecordingStudioAttachable::DirectUrl.normalize_host(host).split("/").first.split(":").first
  rescue StandardError
    nil
  end

  def engine_path?(path)
    path.to_s.start_with?("/dummy_cdn", "/rails", "/assets", "/up")
  end
end
