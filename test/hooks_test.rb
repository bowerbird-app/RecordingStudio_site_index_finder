# frozen_string_literal: true

require "test_helper"

class HooksTest < Minitest::Test
  def test_template_does_not_ship_a_copied_hooks_class
    refute File.exist?(File.expand_path("../lib/recording_studio_site_index_finder/hooks.rb", __dir__))
    refute defined?(RecordingStudio::SiteIndexFinder::Hooks)
  end

  def test_configuration_hooks_are_core_recording_studio_hooks
    configuration = RecordingStudio::SiteIndexFinder::Configuration.new

    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  end

  def test_engine_runs_addon_hooks_through_configuration
    called = false
    RecordingStudio::SiteIndexFinder.configuration.hooks.after_initialize { called = true }

    initializer = RecordingStudio::SiteIndexFinder::Engine.initializers.find do |entry|
      entry.name == "recording_studio_site_index_finder.after_initialize"
    end
    initializer.block.call(Object.new)

    assert called
  ensure
    RecordingStudio::SiteIndexFinder.configuration.hooks.clear!
  end
end
