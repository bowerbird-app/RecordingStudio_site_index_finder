# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    module Robots
      SITEMAP_LINE = /\Asitemap:\s*(\S+)/i

      module_function

      def disguised?(body)
        body.to_s.lstrip.start_with?("<")
      end

      def sitemap_urls(body)
        text = body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        text.each_line.filter_map { |line| sitemap_url(line) }
      end

      def sitemap_url(line)
        stripped = line.strip
        return nil if stripped.empty? || stripped.start_with?("#")

        stripped.match(SITEMAP_LINE)&.[](1)
      end
    end
  end
end
