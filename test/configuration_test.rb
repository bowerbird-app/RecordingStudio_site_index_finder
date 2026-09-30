# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudio::SiteIndexFinder::Configuration.new
  end

  def test_defaults
    assert_equal 5, @configuration.open_timeout
    assert_equal 10, @configuration.read_timeout
    assert_equal 5, @configuration.write_timeout
    assert_equal 5, @configuration.max_redirects
    assert_equal 5_000_000, @configuration.max_response_bytes
    assert_equal 4, @configuration.max_sitemap_depth
    assert_equal 50, @configuration.max_sitemap_count
    assert_equal true, @configuration.instrumentation_enabled?
    assert_nil @configuration.transport
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(open_timeout: 9, max_sitemap_count: 3, instrumentation_enabled: false)

    assert_equal 9, @configuration.open_timeout
    assert_equal 3, @configuration.max_sitemap_count
    assert_equal false, @configuration.instrumentation_enabled?
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", read_timeout: 7)

    refute_respond_to @configuration, :unknown_key
    assert_equal 7, @configuration.read_timeout
  end

  def test_merge_with_non_enumerable_is_noop
    @configuration.merge!(nil)

    assert_equal 5, @configuration.open_timeout
  end

  def test_merge_accepts_string_keys_and_numeric_strings
    @configuration.merge!("max_redirects" => "4", "max_response_bytes" => "1000")

    assert_equal 4, @configuration.max_redirects
    assert_equal 1000, @configuration.max_response_bytes
  end

  def test_invalid_integer_raises_configuration_error
    error = assert_raises(RecordingStudio::SiteIndexFinder::ConfigurationError) do
      @configuration.open_timeout = "soon"
    end

    assert_equal "The configuration value is not an integer", error.message
  end

  def test_to_h_reports_registered_hook_counts_and_hides_transport
    @configuration.transport = Object.new
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
    refute_includes result.keys, :transport
    refute_includes @configuration.inspect, @configuration.transport.inspect
  end

  def test_configure_without_block_is_safe
    RecordingStudio::SiteIndexFinder.configure

    assert_kind_of RecordingStudio::SiteIndexFinder::Configuration, RecordingStudio::SiteIndexFinder.configuration
  end
end
