# frozen_string_literal: true

require "uri"

module RecordingStudio
  module SiteIndexFinder
    module Origin
      SCHEME = %r{\A[a-z][a-z0-9+.-]*://}i

      module_function

      def coerce(value)
        text = value.to_s.strip
        raise InvalidUrlError, "The URL is not valid" if text.empty?

        text = "https://#{text}" unless text.match?(SCHEME)
        uri = Safety.parse(text)
        raise InvalidUrlError, "The URL is not valid" if uri.host.to_s.empty?

        bare(uri).to_s
      end

      def host_hint(value)
        text = value.to_s.strip
        text = "https://#{text}" unless text.match?(SCHEME)
        URI.parse(text).host&.downcase
      rescue URI::InvalidURIError, InvalidUrlError, UnsafeUrlError
        nil
      end

      def same_origin(url)
        bare(Safety.parse(url)).to_s
      end

      def bare(uri)
        copy = uri.dup
        copy.path = "/"
        copy.query = nil
        copy.fragment = nil
        copy.user = nil
        copy.password = nil
        copy
      end
    end
  end
end
