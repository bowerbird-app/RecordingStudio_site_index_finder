# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    Sitemap = Data.define(:url, :type) do
      def to_h
        { "url" => url, "type" => type.to_s }
      end
    end

    IndexedUrl = Data.define(:url, :last_modified_at) do
      def to_h
        { "url" => url, "last_modified_at" => last_modified_at }
      end
    end

    FindingError = Data.define(:code, :message, :url, :status) do
      def initialize(code:, message:, url:, status: nil)
        super
      end

      def to_h
        { "code" => code.to_s, "message" => message, "url" => url, "status" => status }
      end
    end

    class Result
      attr_reader :site_url, :sitemaps, :urls, :errors

      def initialize(site_url:, sitemaps:, urls:, errors:)
        @site_url = site_url
        @sitemaps = sitemaps.freeze
        @urls = urls.freeze
        @errors = errors.freeze
      end

      def url_count
        urls.size
      end

      def status
        return :found if sitemaps.any? && errors.empty?
        return :partial if sitemaps.any?
        return :empty if errors.empty?

        :failed
      end

      def to_h
        {
          "site_url" => site_url,
          "sitemaps" => sitemaps.map(&:to_h),
          "urls" => urls.map(&:to_h),
          "url_count" => url_count,
          "errors" => errors.map(&:to_h),
          "status" => status.to_s
        }
      end
    end
  end
end
