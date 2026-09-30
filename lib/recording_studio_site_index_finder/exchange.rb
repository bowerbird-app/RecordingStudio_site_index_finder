# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module RecordingStudio
  module SiteIndexFinder
    class Exchange
      def self.call(hop)
        new(hop).call
      end

      def initialize(hop)
        @hop = hop
      end

      def call
        perform
      rescue ResponseTooLargeError, TimeoutError, FetchError
        raise
      rescue ::Timeout::Error
        raise TimeoutError, "The request timed out"
      rescue SocketError, OpenSSL::SSL::SSLError, IOError, SystemCallError
        raise FetchError, "The site could not be fetched"
      end

      private

      def perform
        request = Net::HTTP::Get.new(URI(@hop.fetch(:url)))
        request["User-Agent"] = @hop.fetch(:user_agent).to_s
        request["Accept"] = "application/xml, text/xml, text/plain, */*;q=0.1"
        http_client.request(request) { |response| return read_response(response) }
      end

      def http_client
        http = Net::HTTP.new(@hop.fetch(:host), @hop.fetch(:port))
        http.ipaddr = @hop.fetch(:address)
        configure_tls(http)
        apply_timeouts(http)
        http.max_retries = 0 if http.respond_to?(:max_retries=)
        http
      end

      def configure_tls(http)
        http.use_ssl = @hop.fetch(:https)
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if @hop.fetch(:https)
      end

      def apply_timeouts(http)
        timeouts = @hop.fetch(:timeouts)
        http.open_timeout = timeouts.fetch(:open)
        http.read_timeout = timeouts.fetch(:read)
        http.write_timeout = timeouts.fetch(:write)
      end

      def read_response(response)
        headers = {}
        response.each_header { |name, value| headers[name.downcase] = value }
        reject_declared_size!(headers)

        {
          status: response.code.to_i,
          headers: headers,
          body: read_body(response),
          location: headers["location"],
          address: @hop.fetch(:address)
        }
      end

      def reject_declared_size!(headers)
        declared = headers["content-length"].to_i
        return if declared <= @hop.fetch(:max_bytes)

        raise ResponseTooLargeError, "The response was too large"
      end

      def read_body(response)
        body = +""
        max_bytes = @hop.fetch(:max_bytes)
        response.read_body do |chunk|
          body << chunk
          raise ResponseTooLargeError, "The response was too large" if body.bytesize > max_bytes
        end
        body
      end
    end
  end
end
