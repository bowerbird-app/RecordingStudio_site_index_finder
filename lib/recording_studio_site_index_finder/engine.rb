# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    module ConfigLoader
      CONFIG_KEY = :recording_studio_site_index_finder

      def merge_recorded_config(app)
        merge_yaml(app)
        merge_rails_config(app)
      end

      private

      def merge_yaml(app)
        yaml = yaml_config(app)
        configuration.merge!(yaml) if yaml.respond_to?(:each)
      rescue StandardError
        nil
      end

      def yaml_config(app)
        return nil unless app.respond_to?(:config_for)

        app.config_for(CONFIG_KEY)
      rescue StandardError
        nil
      end

      def merge_rails_config(app)
        return unless rails_config?(app)

        hash = rails_config_hash(app.config.x.public_send(CONFIG_KEY))
        configuration.merge!(hash) if hash.respond_to?(:each)
      rescue StandardError
        nil
      end

      def rails_config?(app)
        app.config.respond_to?(:x) && app.config.x.respond_to?(CONFIG_KEY)
      end

      def rails_config_hash(value)
        return value.to_h if value.respond_to?(:to_h)
        return nil unless value.respond_to?(:each_pair)

        hash = {}
        value.each_pair { |key, entry| hash[key] = entry }
        hash
      end

      def configuration
        SiteIndexFinder.configuration
      end
    end

    module ExtensionApplier
      APPLIED = :@recording_studio_site_index_finder_applied_extensions

      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      private

      def extensions_for(kind, names)
        hooks = SiteIndexFinder.configuration.hooks
        Array(names).flat_map do |name|
          kind == :model ? hooks.model_extensions_for(name) : hooks.controller_extensions_for(name)
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(APPLIED) || {}.compare_by_identity
        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end
        target.instance_variable_set(APPLIED, applied)
      end

      def extension_keys_for(target)
        [target.name, target.name&.demodulize].compact.uniq.map(&:to_sym)
      end
    end

    class Engine < ::Rails::Engine
      include ConfigLoader
      extend ExtensionApplier

      isolate_namespace RecordingStudio::SiteIndexFinder

      initializer "recording_studio_site_index_finder.before_initialize",
                  before: "recording_studio_site_index_finder.load_config" do |_app|
        SiteIndexFinder.configuration.hooks.run(:before_initialize, self)
      end

      initializer "recording_studio_site_index_finder.load_config" do |app|
        merge_recorded_config(app)
        SiteIndexFinder.configuration.hooks.run(:on_configuration, SiteIndexFinder.configuration)
      end

      initializer "recording_studio_site_index_finder.after_initialize",
                  after: "recording_studio_site_index_finder.load_config" do |_app|
        SiteIndexFinder.configuration.hooks.run(:after_initialize, self)
      end

      initializer "recording_studio_site_index_finder.apply_model_extensions" do
        config.to_prepare do
          next unless defined?(ActiveRecord::Base)

          ActiveRecord::Base.descendants.each do |model|
            next if model.abstract_class?

            Engine.apply_model_extensions(model)
          end
        end
      end

      initializer "recording_studio_site_index_finder.apply_controller_extensions" do
        config.to_prepare do
          next unless defined?(ActionController::Base)

          ActionController::Base.descendants.each do |controller|
            Engine.apply_controller_extensions(controller)
          end
        end
      end
    end
  end
end
