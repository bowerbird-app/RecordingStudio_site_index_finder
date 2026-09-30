# frozen_string_literal: true

require "uri"
require "zlib"

module RecordingStudio
  module SiteIndexFinder
    class Client
      REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze
      Response = Data.define(:status, :body, :final_url, :headers)

      def initialize(configuration, payload)
        @configuration = configuration
        @payload = payload
      end

      def get(url)
        current = url
        followed = 0
        seen = {}
        loop do
          destination = Safety.resolve!(current)
          raw = exchange(destination)
          return response_for(destination, raw) unless redirect?(raw)

          followed += 1
          current = next_url(destination, raw, followed, seen)
        end
      end

      private

      def exchange(destination)
        @payload[:request_count] += 1
        raw = transport(destination)
        reported = raw[:address].to_s
        raise UnsafeUrlError, "The URL is not allowed" if reported != destination.address.to_s

        raw
      end

      def transport(destination)
        hop = hop_for(destination)
        return @configuration.transport.call(hop) if @configuration.transport

        Exchange.call(hop)
      end

      def hop_for(destination)
        destination.to_h.merge(
          user_agent: @configuration.user_agent,
          max_bytes: @configuration.max_response_bytes,
          timeouts: timeouts
        )
      end

      def timeouts
        {
          open: @configuration.open_timeout,
          read: @configuration.read_timeout,
          write: @configuration.write_timeout
        }
      end

      def redirect?(raw)
        REDIRECT_STATUSES.include?(raw[:status].to_i)
      end

      def next_url(destination, raw, followed, seen)
        raise TooManyRedirectsError, "The site redirected too many times" if followed > @configuration.max_redirects

        nxt = URI.join(destination.url, redirect_location(raw)).to_s
        raise TooManyRedirectsError, "The site redirected too many times" if seen[nxt]

        seen[nxt] = true
        nxt
      end

      def redirect_location(raw)
        location = raw[:location].to_s.strip
        location = raw.dig(:headers, "location").to_s.strip if location.empty?
        raise FetchError, "The redirect location was empty" if location.empty?

        location
      end

      def response_for(destination, raw)
        Response.new(
          status: raw[:status].to_i,
          body: decode_body(raw),
          final_url: destination.url,
          headers: raw[:headers] || {}
        )
      end

      def decode_body(raw)
        body = raw[:body].to_s
        body = Zlib.gunzip(body) if gzip_bytes?(body)
        raise ResponseTooLargeError, "The response was too large" if body.bytesize > @configuration.max_response_bytes

        body
      rescue Zlib::Error
        raise FetchError, "The response could not be read"
      end

      def gzip_bytes?(body)
        body.b.start_with?("\x1f\x8b".b)
      end
    end
  end
end
