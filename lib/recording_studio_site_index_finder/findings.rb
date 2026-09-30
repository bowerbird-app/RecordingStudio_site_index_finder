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

      def record(code, message, url)
        @errors << FindingError.new(code: code, message: message, url: url)
      end

      def to_result(site_url)
        pages = @urls.map { |url, last_modified_at| IndexedUrl.new(url: url, last_modified_at: last_modified_at) }
        Result.new(site_url: site_url, sitemaps: @sitemaps, urls: pages, errors: @errors)
      end
    end
  end
end
