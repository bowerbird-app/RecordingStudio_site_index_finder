# frozen_string_literal: true

module RecordingStudio
  module SiteIndexFinder
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception
      layout "application"
    end
  end
end
