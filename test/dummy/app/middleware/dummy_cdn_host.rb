# frozen_string_literal: true

# When the request Host matches Attachable's direct_url_host, rewrite the path
# to the dummy CDN controller so https://cdn.example.test/<blob key> works
# against the local Rails process (hosts file / local DNS required).
class DummyCdnHost
  def initialize(app)
    @app = app
  end

  def call(env)
    host = env["HTTP_HOST"].to_s.split(":").first
    direct_host = direct_url_host_name
    if direct_host.present? && host == direct_host && !engine_path?(env["PATH_INFO"])
      env = env.dup
      env["PATH_INFO"] = "/dummy_cdn#{env["PATH_INFO"]}"
      env["SCRIPT_NAME"] = ""
      env["REQUEST_URI"] = env["PATH_INFO"]
    end
    @app.call(env)
  end

  private

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
