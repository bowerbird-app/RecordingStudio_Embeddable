# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "pathname"

module RecordingStudioEmbeddable
  # One stylesheet for every embed document.
  #
  # Tailwind scans the gem embed templates, FlatPack components, and
  # +config.embed_view_paths+. The build also inlines FlatPack theme variables
  # and component rules, and the Inter faces, so the document does not request
  # the host origin. +digest+ is the cache and CDN publish key for that CSS.
  class EmbedStylesheet
    LAYOUT_CSS = <<~CSS
      .recording-studio-embed-layout {
        margin: 0;
        min-height: 100%;
        background: var(--surface-background-color, transparent);
        color: var(--surface-content-color, inherit);
      }

      .recording-studio-embed-layout a {
        color: var(--color-primary, currentColor);
      }

      .recording-studio-embed-layout [data-recording-studio-embeddable="fallback"] {
        color: var(--surface-content-color, inherit);
      }

      .recording-studio-embed-layout [data-recording-studio-embeddable="fallback"] p {
        color: var(--surface-muted-content-color, inherit);
      }
    CSS
    FONT_URL = /url\((['"]?)(?:[^)'"]*?)inter-latin-(\d+)\.woff2(?:\?[^)'"]*)?\1\)/
    LOCK = Mutex.new

    class << self
      def css
        if rails_root
          ensure_built!
          File.read(output_path)
        else
          fallback_css
        end
      end

      def digest
        Digest::SHA256.hexdigest(css)
      end

      def build!
        raise "Rails.root is required to build embed CSS" unless rails_root

        FileUtils.mkdir_p(output_path.dirname)
        FileUtils.mkdir_p(work_dir)
        File.write(component_css_path, component_css)
        File.write(input_path, input_css)
        compile(input_path, output_path)
        File.write(output_path, inline_fonts(File.read(output_path)))
        File.write(stamp_path, source_fingerprint)
        @ready = true
        output_path
      end

      def source_paths
        paths = [
          Engine.root.join("app/views/recording_studio_embeddable/embeds"),
          Engine.root.join("app/views/layouts/recording_studio_embeddable/embed.html.erb"),
          Engine.root.join("app/views/layouts/recording_studio_embeddable/iframe.html.erb"),
          flatpack_root.join("app/components")
        ]
        Array(configuration.embed_view_paths).each do |entry|
          path = Pathname(entry.to_s)
          raise ArgumentError, "embed view path does not exist: #{path}" unless path.exist?

          paths << path
        end
        paths
      end

      def republish_stale_embeds!
        return 0 unless embeds_ready?

        current = digest
        count = 0
        Embed.find_each do |embed|
          next unless embed.respond_to?(:cdn_url_strategy?) && embed.cdn_url_strategy?
          next if stored_stylesheet_digest(embed) == current
          next unless embed.enqueue_cdn_publish!

          count += 1
        end
        count
      rescue StandardError
        0
      end

      def reset!
        @ready = false
      end

      private

      def ensure_built!
        return if usable?

        LOCK.synchronize do
          return if usable?

          build!
        end
      end

      def usable?
        return false unless output_path.file?

        fresh = stamp_path.file? && stamp_path.read == source_fingerprint
        return fresh if development?
        return true if @ready
        return false unless fresh

        @ready = true
        true
      end

      def configuration
        RecordingStudioEmbeddable.configuration
      end

      def input_css
        lines = [
          "@import \"tailwindcss\";",
          %(@import "#{variables_path}";),
          %(@import "#{component_css_path}";)
        ]
        extra_stylesheets.each { |path| lines << %(@import "#{path}";) }
        source_paths.each { |path| lines << %(@source "#{path}";) }
        "#{lines.join("\n")}\n#{LAYOUT_CSS}"
      end

      def component_css
        File.read(application_path).lines.reject { |line| line.lstrip.start_with?("@import") }.join
      end

      def extra_stylesheets
        Array(configuration.embed_stylesheet_paths).map do |entry|
          path = Pathname(entry.to_s)
          raise ArgumentError, "embed stylesheet path does not exist: #{path}" unless path.file?

          path
        end
      end

      def compile(input, output)
        command = [tailwind_executable.to_s, "--input", input.to_s, "--output", output.to_s, "--minify"]
        success = system(*command, exception: false)
        return if success

        raise "tailwindcss failed while building the embed stylesheet (#{command.join(' ')})"
      end

      def tailwind_executable
        require "tailwindcss/ruby"
        Pathname(Tailwindcss::Ruby.executable)
      rescue LoadError
        raise "Install tailwindcss-rails so the embed stylesheet can be built"
      end

      def inline_fonts(css)
        css.gsub(FONT_URL) do
          weight = Regexp.last_match(2)
          file = flatpack_root.join("app/assets/fonts/flat_pack/inter-latin-#{weight}.woff2")
          raise "FlatPack font is missing: #{file}" unless file.file?

          %(url("data:font/woff2;base64,#{Base64.strict_encode64(file.binread)}"))
        end
      end

      def fallback_css
        @fallback_css ||= inline_fonts("#{File.read(variables_path)}\n#{component_css}\n#{LAYOUT_CSS}")
      end

      def source_fingerprint
        parts = [input_css_for_fingerprint]
        watched_files.each do |path|
          next unless path.file?

          stat = path.stat
          parts << "#{path}:#{stat.mtime.to_i}:#{stat.size}"
        end
        Digest::SHA256.hexdigest(parts.join("\n"))
      end

      # The real input names a temp components file. The fingerprint uses the
      # FlatPack source path so a rebuild is not required just to hash the temp file.
      def input_css_for_fingerprint
        lines = source_paths.map(&:to_s) + extra_stylesheets.map(&:to_s)
        lines << LAYOUT_CSS
        lines.join("\n")
      end

      def watched_files
        files = [variables_path, application_path, *extra_stylesheets]
        source_paths.each do |path|
          if path.file?
            files << path
          elsif path.directory?
            Dir.glob(path.join("**/*.{rb,erb,html,css,js}")).each { |file| files << Pathname(file) }
          end
        end
        files
      end

      def stored_stylesheet_digest(embed)
        metadata = embed.try(:metadata)
        return unless metadata.respond_to?(:dig)

        metadata.dig("artifact", "stylesheet_digest")
      end

      def embeds_ready?
        return false unless defined?(Embed)
        return false unless Embed.respond_to?(:connected?) && Embed.connected?

        Embed.table_exists?
      rescue StandardError
        false
      end

      def output_path
        rails_root.join("app/assets/builds/recording_studio_embeddable/embed.css")
      end

      def stamp_path
        rails_root.join("app/assets/builds/recording_studio_embeddable/embed.css.stamp")
      end

      def work_dir
        rails_root.join("tmp/recording_studio_embeddable")
      end

      def input_path
        work_dir.join("embed.input.css")
      end

      def component_css_path
        work_dir.join("components.css")
      end

      def variables_path
        flatpack_root.join("app/assets/stylesheets/flat_pack/variables.css")
      end

      def application_path
        flatpack_root.join("app/assets/stylesheets/flat_pack/application.css")
      end

      def flatpack_root
        require "flat_pack" unless defined?(FlatPack::Engine)
        Pathname(FlatPack::Engine.root)
      end

      def rails_root
        return unless defined?(Rails) && Rails.respond_to?(:root)

        root = Rails.root
        Pathname(root) if root.present?
      rescue StandardError
        nil
      end

      def development?
        defined?(Rails) && Rails.respond_to?(:env) && Rails.env.development?
      end
    end
  end
end
