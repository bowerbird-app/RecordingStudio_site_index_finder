# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    class HomeController < ApplicationController
      def index
        head :ok
      end
    end
  end
end
