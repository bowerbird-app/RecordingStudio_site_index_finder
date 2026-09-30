# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    class Findings
      ERROR_CODES = {
        UnsafeUrlError => :unsafe,
        InvalidUrlError => :url,
        TimeoutError => :timeout,
        ResponseTooLargeError => :too_large,
        TooManyRedirectsError => :redirect,
        FetchError => :fetch,
        SitemapDocument::ParseError => :malformed_xml
      }.freeze
      LIMIT_MESSAGES = {
        depth: "The sitemap depth limit was reached",
        limit: "The sitemap limit was reached"
      }.freeze
      RESTRICTED_SITEMAP = [401, 403].freeze
      REFUSED_ROBOTS = [401, 403, 418, 429].freeze

      def initialize
        @sitemaps = []
        @urls = {}
        @errors = []
      end

      def empty?
        @sitemaps.empty?
      end

      def size
        @sitemaps.size
      end

      def add_sitemap(url, type)
        @sitemaps << Sitemap.new(url: url, type: type)
      end

      def add_page(page)
        url = Location.page(page.url)
        return record(:url, "A sitemap URL was not valid", page.url) if url.nil?
        return if @urls.key?(url)

        @urls[url] = page.last_modified_at
      end

      def record_note(note)
        return if note.nil?

        record(note.code, LIMIT_MESSAGES.fetch(note.code), note.url)
      end

      def record_exception(error, url)
        record(ERROR_CODES.fetch(error.class, :fetch), error.message, url)
      end

      def record_sitemap_failure(status, url)
        code, message = sitemap_failure(status)
        record(code, message, url, status: status)
      end

      def record_robots_failure(status, url)
        message = REFUSED_ROBOTS.include?(status) ? "robots.txt refused the request" : "robots.txt could not be read"
        record(:robots, message, url, status: status)
      end

      def record(code, message, url, status: nil)
        @errors << FindingError.new(code: code, message: message, url: url, status: status)
      end

      def to_result(site_url)
        pages = @urls.map { |url, last_modified_at| IndexedUrl.new(url: url, last_modified_at: last_modified_at) }
        Result.new(site_url: site_url, sitemaps: @sitemaps, urls: pages, errors: @errors)
      end

      private

      def sitemap_failure(status)
        return [:forbidden, "The sitemap is restricted"] if RESTRICTED_SITEMAP.include?(status)

        [:http, "The sitemap request failed"]
      end
    end
  end
end
