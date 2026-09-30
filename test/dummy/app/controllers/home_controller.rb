# frozen_string_literal: true

class HomeController < ApplicationController
  PREVIEW_LIMIT = 200
  STATUS_LABELS = {
    found: "Found",
    partial: "Found with errors",
    empty: "No sitemap found",
    failed: "Discovery failed"
  }.freeze

  helper_method :site_index_status_label

  def index
    @supplied_url = params[:url].to_s
    @preview_limit = PREVIEW_LIMIT
    return if @supplied_url.strip.empty?

    @result = RecordingStudio::SiteIndexFinder.find(@supplied_url)
  rescue RecordingStudio::SiteIndexFinder::Error => e
    @failure = e
  end

  def site_index_status_label(result)
    STATUS_LABELS.fetch(result.status)
  end
end
