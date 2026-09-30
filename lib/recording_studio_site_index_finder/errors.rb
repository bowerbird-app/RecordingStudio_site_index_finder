# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    class Error < StandardError; end

    class ConfigurationError < Error; end
    class InvalidUrlError < Error; end
    class UnsafeUrlError < Error; end
    class FetchError < Error; end
    class TimeoutError < FetchError; end
    class TooManyRedirectsError < Error; end
    class ResponseTooLargeError < Error; end
  end
end
