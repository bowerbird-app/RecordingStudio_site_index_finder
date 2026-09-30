# frozen_string_literal: true

require "uri"

module RecordingStudio
  module SiteIndexFinder
    module Location
      module_function

      def join(base_url, loc)
        absolute = URI.join(base_url, loc.to_s.strip)
        return nil unless absolute.is_a?(URI::HTTP)

        without_fragment(absolute)
      rescue URI::InvalidURIError
        nil
      end

      def page(value)
        uri = URI.parse(value.to_s.strip)
        return nil unless uri.is_a?(URI::HTTP)
        return nil if uri.host.to_s.empty?

        without_fragment(uri)
      rescue URI::InvalidURIError
        nil
      end

      def without_fragment(uri)
        uri.fragment = nil
        uri.to_s
      end
    end
  end
end
