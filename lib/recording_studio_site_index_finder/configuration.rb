# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    class Configuration
      DEFAULT_OPEN_TIMEOUT = 5
      DEFAULT_READ_TIMEOUT = 10
      DEFAULT_WRITE_TIMEOUT = 5
      DEFAULT_MAX_REDIRECTS = 5
      DEFAULT_MAX_RESPONSE_BYTES = 5_000_000
      DEFAULT_MAX_SITEMAP_DEPTH = 4
      DEFAULT_MAX_SITEMAP_COUNT = 50

      attr_accessor :user_agent, :instrumentation_enabled, :transport
      attr_reader :hooks

      def initialize
        @open_timeout = nil
        @read_timeout = nil
        @max_redirects = nil
        @max_response_bytes = nil
        @max_sitemap_depth = nil
        @max_sitemap_count = nil
        @instrumentation_enabled = true
        @transport = nil
        @user_agent = "RecordingStudioSiteIndexFinder/#{VERSION}"
        @hooks = RecordingStudio::Hooks.new
      end

      def open_timeout
        @open_timeout || DEFAULT_OPEN_TIMEOUT
      end

      def read_timeout
        @read_timeout || DEFAULT_READ_TIMEOUT
      end

      def write_timeout
        DEFAULT_WRITE_TIMEOUT
      end

      def max_redirects
        @max_redirects || DEFAULT_MAX_REDIRECTS
      end

      def max_response_bytes
        @max_response_bytes || DEFAULT_MAX_RESPONSE_BYTES
      end

      def max_sitemap_depth
        @max_sitemap_depth || DEFAULT_MAX_SITEMAP_DEPTH
      end

      def max_sitemap_count
        @max_sitemap_count || DEFAULT_MAX_SITEMAP_COUNT
      end

      def instrumentation_enabled?
        @instrumentation_enabled != false
      end

      def open_timeout=(value)
        @open_timeout = optional_integer(value)
      end

      def read_timeout=(value)
        @read_timeout = optional_integer(value)
      end

      def max_redirects=(value)
        @max_redirects = optional_integer(value)
      end

      def max_response_bytes=(value)
        @max_response_bytes = optional_integer(value)
      end

      def max_sitemap_depth=(value)
        @max_sitemap_depth = optional_integer(value)
      end

      def max_sitemap_count=(value)
        @max_sitemap_count = optional_integer(value)
      end

      def to_h
        {
          open_timeout: open_timeout, read_timeout: read_timeout, write_timeout: write_timeout,
          max_redirects: max_redirects, max_response_bytes: max_response_bytes,
          max_sitemap_depth: max_sitemap_depth, max_sitemap_count: max_sitemap_count,
          instrumentation_enabled: instrumentation_enabled?, user_agent: user_agent,
          hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
        }
      end

      def inspect
        "#<#{self.class.name} #{to_h.inspect}>"
      end

      def merge!(hash)
        return unless hash.respond_to?(:each)

        hash.each do |key, value|
          setter = "#{key}="
          public_send(setter, value) if respond_to?(setter)
        end
      end

      private

      def optional_integer(value)
        return nil if value.nil?

        Integer(value)
      rescue ArgumentError, TypeError
        raise ConfigurationError, "The configuration value is not an integer"
      end
    end
  end
end
