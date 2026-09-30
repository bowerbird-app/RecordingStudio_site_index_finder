# frozen_string_literal: true

require "active_support/notifications"

module RecordingStudio
  module SiteIndexFinder
    class Finder
      def self.call(url)
        new(url).call
      end

      def initialize(url)
        @url = url
        @started = monotonic
        @payload = blank_payload
      end

      def call
        return run unless SiteIndexFinder.configuration.instrumentation_enabled?

        ActiveSupport::Notifications.instrument(SiteIndexFinder::EVENT_NAME, @payload) { run }
      end

      private

      def run
        result = discover
        record_success(result)
        result
      rescue Error => e
        record_failure(e)
        raise
      ensure
        @payload[:duration_ms] = elapsed
      end

      def blank_payload
        {
          schema_version: 1,
          host: nil,
          success: false,
          request_count: 0,
          sitemap_count: 0,
          url_count: 0,
          error_type: nil,
          duration_ms: nil
        }
      end

      def record_success(result)
        @payload[:success] = true
        @payload[:error_type] = result.errors.first&.code&.to_s
        @payload[:sitemap_count] = result.sitemaps.size
        @payload[:url_count] = result.url_count
      end

      def record_failure(error)
        @payload[:host] ||= Origin.host_hint(@url)
        @payload[:error_type] = error.class.name
      end

      def discover
        origin = Origin.coerce(@url)
        @payload[:host] = URI(origin).host&.downcase
        Discovery.new(origin, SiteIndexFinder.configuration, @payload).call
      end

      def elapsed
        ((monotonic - @started) * 1000).round
      end

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
