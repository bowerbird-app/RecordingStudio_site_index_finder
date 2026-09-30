# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudio
  module SiteIndexFinder
    module Generators
      class MigrationsGenerator < Rails::Generators::Base
        include ActiveRecord::Generators::Migration

        source_root File.expand_path("../../../..", __dir__)

        desc "Copy Site Index Finder migrations to your application"

        class_option :skip_existing, type: :boolean, default: true,
                                     desc: "Skip migrations that already exist (based on name, ignoring timestamp)"

        def copy_migrations
          migrations_dir = File.join(self.class.source_root, "db", "migrate")
          return say("No migrations found in Site Index Finder.", :yellow) unless File.directory?(migrations_dir)

          migration_files = Dir.glob(File.join(migrations_dir, "*.rb"))
          return say("No migrations found in Site Index Finder.", :yellow) if migration_files.empty?

          install_migrations(migration_files)
        end

        private

        def install_migrations(migration_files)
          say "Found #{migration_files.size} migration(s) to install:", :green
          migration_files.each { |source_path| install_migration(source_path) }
          say "\nRun 'bin/rails db:migrate' to apply the migrations.", :green
        end

        def install_migration(source_path)
          migration_name = File.basename(source_path).sub(/^\d+_/, "")
          if options[:skip_existing] && migration_exists?(migration_name)
            say "  skip  #{migration_name} (already exists)", :yellow
            return
          end

          destination_path = File.join("db/migrate", "#{next_migration_number}_#{migration_name}")
          copy_file source_path, destination_path
          say "  create  #{destination_path}", :green
          sleep 0.1
        end

        def migration_exists?(migration_name)
          Dir.glob(File.join(destination_root, "db/migrate", "*_#{migration_name}")).any?
        end

        def next_migration_number
          ActiveRecord::Migration.next_migration_number(Time.now.utc.strftime("%Y%m%d%H%M%S"))
        end
      end
    end
  end
end
