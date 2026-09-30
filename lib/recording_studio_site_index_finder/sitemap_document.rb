# frozen_string_literal: true

require "rexml/document"
require "stringio"

module RecordingStudio
  module SiteIndexFinder
    class SitemapDocument
      class ParseError < Error; end

      Document = Data.define(:type, :children, :pages)
      OPTIONS = { entity_expansion_limit: 32 }.freeze

      def self.parse(xml)
        new(xml).parse
      end

      def initialize(xml)
        @xml = Text.utf8(xml)
      end

      def parse
        root = parsed_root
        case root.name
        when "urlset" then Document.new(type: :urlset, children: [], pages: pages_under(root, "url"))
        when "sitemapindex" then Document.new(type: :index, children: locations_under(root, "sitemap"), pages: [])
        else raise ParseError, "The sitemap root was not recognized"
        end
      rescue REXML::ParseException, EncodingError
        raise ParseError, "The sitemap XML could not be parsed"
      end

      private

      def parsed_root
        document = REXML::Document.new(StringIO.new(@xml), OPTIONS)
        document.root || raise(ParseError, "The sitemap XML could not be parsed")
      end

      def pages_under(root, name)
        elements_named(root, name).filter_map { |node| page_for(node) }
      end

      def locations_under(root, name)
        elements_named(root, name).filter_map { |node| text_of(node, "loc") }
      end

      def page_for(node)
        loc = text_of(node, "loc")
        return nil if loc.nil?

        IndexedUrl.new(url: loc, last_modified_at: text_of(node, "lastmod"))
      end

      def elements_named(node, name)
        node.elements.select { |child| child.name == name }
      end

      def text_of(node, name)
        child = node.elements.find { |element| element.name == name }
        value = child&.text.to_s.strip
        value.empty? ? nil : value
      end
    end
  end
end
