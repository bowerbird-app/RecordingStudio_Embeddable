# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioEmbeddable
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("../../../..", __dir__)

      desc "Copy RecordingStudioEmbeddable migrations to your application"

      class_option :skip_existing, type: :boolean, default: true,
                                   desc: "Skip migrations that already exist based on name"

      def copy_migrations
        Dir.glob(File.join(self.class.source_root, "db/migrate/*.rb")).each do |source_path|
          migration_name = File.basename(source_path).sub(/^\d+_/, "")
          if options[:skip_existing] && migration_exists?(migration_name)
            next say("  skip  #{migration_name} (already exists)",
                     :yellow)
          end

          destination = File.join("db/migrate", "#{next_migration_number}_#{migration_name}")
          copy_file source_path, destination
          sleep 0.1
        end

        say "Run 'bin/rails db:migrate' to apply the migrations.", :green
      end

      private

      def migration_exists?(migration_name)
        Dir.glob(File.join(destination_root, "db/migrate", "*_#{migration_name}")).any?
      end

      def next_migration_number
        ActiveRecord::Migration.next_migration_number(Dir.glob(File.join(destination_root, "db/migrate/*.rb")).size + 1)
      end
    end
  end
end
