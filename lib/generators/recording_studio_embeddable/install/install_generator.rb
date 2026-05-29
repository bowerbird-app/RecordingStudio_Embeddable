# frozen_string_literal: true

require "rails/generators"

module RecordingStudioEmbeddable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioEmbeddable into your application"

      class_option :mount_path, type: :string, default: "/recording_studio_embeddable",
                                desc: "Route prefix used when mounting the engine"

      def mount_engine
        route %(mount RecordingStudioEmbeddable::Engine, at: "#{options[:mount_path]}")
      end

      def copy_initializer
        template "recording_studio_embeddable_initializer.rb", "config/initializers/recording_studio_embeddable.rb"
      end

      def install_migrations
        generate "recording_studio_embeddable:migrations"
      end

      def add_yaml_config
        return unless yes?("Would you like to add `config/recording_studio_embeddable.yml`? [y/N]")

        template "recording_studio_embeddable.yml", "config/recording_studio_embeddable.yml"
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
