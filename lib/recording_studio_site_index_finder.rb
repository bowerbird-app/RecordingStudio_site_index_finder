# frozen_string_literal: true

require "recording_studio"
require "recording_studio_site_index_finder/version"
require "recording_studio_site_index_finder/errors"
require "recording_studio_site_index_finder/configuration"
require "recording_studio_site_index_finder/result"
require "recording_studio_site_index_finder/safety"
require "recording_studio_site_index_finder/exchange"
require "recording_studio_site_index_finder/client"
require "recording_studio_site_index_finder/origin"
require "recording_studio_site_index_finder/text"
require "recording_studio_site_index_finder/location"
require "recording_studio_site_index_finder/sitemap_queue"
require "recording_studio_site_index_finder/robots"
require "recording_studio_site_index_finder/sitemap_document"
require "recording_studio_site_index_finder/findings"
require "recording_studio_site_index_finder/discovery"
require "recording_studio_site_index_finder/finder"
require "recording_studio_site_index_finder/engine"

module RecordingStudio
  module SiteIndexFinder
    EVENT_NAME = "find.recording_studio_site_index_finder"

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration) if block_given?
      end

      def find(url)
        Finder.call(url)
      end
    end
  end
end
