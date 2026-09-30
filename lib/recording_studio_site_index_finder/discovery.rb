# frozen_string_literal: true

require "uri"

module RecordingStudio
  module SiteIndexFinder
    class Discovery
      CONVENTIONAL_PATHS = %w[sitemap.xml sitemap_index.xml sitemap-index.xml].freeze

      def initialize(origin_url, configuration, payload)
        @origin_url = origin_url
        @client = Client.new(configuration, payload)
        @findings = Findings.new
        @queue = SitemapQueue.new(configuration)
      end

      def call
        site_url = resolve_site
        read_robots(site_url)
        drain
        read_conventional(site_url) if @findings.empty?
        @findings.to_result(site_url)
      end

      private

      def resolve_site
        response = @client.get(@origin_url)
        Origin.same_origin(response.final_url)
      rescue UnsafeUrlError, InvalidUrlError
        raise
      rescue Error => e
        @findings.record_exception(e, @origin_url)
        @origin_url
      end

      def read_robots(site_url)
        url = URI.join(site_url, "robots.txt").to_s
        response = @client.get(url)
        collect_declarations(site_url, url, response)
      rescue EncodingError
        @findings.record(:robots, "robots.txt could not be read", url)
      rescue Error => e
        @findings.record_exception(e, url)
      end

      def collect_declarations(site_url, url, response)
        return @findings.record_robots_failure(response.status, url) if unreadable_robots?(response)
        return if response.status != 200
        if Robots.disguised?(response.body)
          return @findings.record(:robots, "robots.txt was not a robots file", url, status: response.status)
        end

        Robots.sitemap_urls(response.body).each { |loc| enqueue(site_url, loc, 0) }
      end

      def unreadable_robots?(response)
        response.status >= 400 && response.status != 404
      end

      def read_conventional(site_url)
        CONVENTIONAL_PATHS.each do |path|
          break unless @findings.empty?

          enqueue_absolute(URI.join(site_url, path).to_s, 0, conventional: true)
          drain
        end
      end

      def drain
        while (item = @queue.shift)
          if @queue.stopped?(@findings.size)
            @findings.record_note(@queue.note(:limit, item[:url]))
            break
          end

          process(item)
        end
      end

      def process(item)
        response = @client.get(item[:url])
        handle_response(item, response)
      rescue SitemapDocument::ParseError => e
        @findings.record(:malformed_xml, e.message, item[:url])
      rescue EncodingError
        @findings.record(:malformed_xml, "The sitemap XML could not be parsed", item[:url])
      rescue Error => e
        @findings.record_exception(e, item[:url])
      end

      def handle_response(item, response)
        return missing_sitemap(item, response.status) if response.status == 404
        return @findings.record_sitemap_failure(response.status, item[:url]) unless success?(response)

        store(item[:url], SitemapDocument.parse(response.body), item[:depth])
      end

      def success?(response)
        response.status.between?(200, 299)
      end

      def missing_sitemap(item, status)
        return if item[:conventional]

        @findings.record(:missing, "The sitemap was not found", item[:url], status: status)
      end

      def store(url, document, depth)
        @findings.add_sitemap(url, document.type)
        return expand(url, document, depth) if document.type == :index

        document.pages.each { |page| @findings.add_page(page) }
      end

      def expand(url, document, depth)
        document.children.each { |loc| enqueue(url, loc, depth + 1) }
      end

      def enqueue(base_url, loc, depth)
        absolute = Location.join(base_url, loc)
        return @findings.record(:url, "A sitemap URL was not valid", loc) if absolute.nil?

        enqueue_absolute(absolute, depth, conventional: false)
      end

      def enqueue_absolute(url, depth, conventional:)
        @findings.record_note(@queue.add(url, depth, conventional: conventional))
      end
    end
  end
end
