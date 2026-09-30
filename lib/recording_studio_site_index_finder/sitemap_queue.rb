# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    class SitemapQueue
      Note = Data.define(:code, :url)

      def initialize(configuration)
        @configuration = configuration
        @seen = {}
        @items = []
        @noted = {}
      end

      def shift
        @items.shift
      end

      def stopped?(sitemap_count)
        sitemap_count >= @configuration.max_sitemap_count
      end

      def add(url, depth, conventional:)
        return if @seen[url]
        return note(:depth, url) if depth > @configuration.max_sitemap_depth
        return note(:limit, url) if @seen.size >= @configuration.max_sitemap_count

        @seen[url] = true
        @items << { url: url, depth: depth, conventional: conventional }
        nil
      end

      def note(code, url)
        return if @noted[code]

        @noted[code] = true
        Note.new(code: code, url: url)
      end
    end
  end
end
