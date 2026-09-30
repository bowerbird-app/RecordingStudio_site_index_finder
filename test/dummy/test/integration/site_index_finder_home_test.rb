# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "resolv"

class SiteIndexFinderHomeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  PUBLIC_IP = "93.184.216.34"

  setup do
    @original = RecordingStudio::SiteIndexFinder.instance_variable_get(:@configuration)
    RecordingStudio::SiteIndexFinder.instance_variable_set(
      :@configuration,
      RecordingStudio::SiteIndexFinder::Configuration.new
    )
    sign_in finder_user
    prepare_workspace
  end

  teardown do
    RecordingStudio::SiteIndexFinder.instance_variable_set(:@configuration, @original)
  end

  test "home page offers the finder form" do
    get root_path

    assert_response :success
    assert_includes response.body, "Find site index"
    assert_includes response.body, "Site URL"
    refute_includes response.body, "Resolved site URL"
  end

  test "submitting a public site shows the discovered sitemap and urls" do
    RecordingStudio::SiteIndexFinder.configuration.transport = scripted_site

    with_public_dns do
      get root_path, params: { url: "https://example.com" }
    end

    assert_response :success
    assert_includes response.body, "https://example.com"
    assert_includes response.body, "https://example.com/"
    assert_includes response.body, "Found"
    assert_includes response.body, "https://example.com/sitemap.xml"
    assert_includes response.body, "urlset"
    assert_includes response.body, "https://example.com/a"
    assert_includes response.body, "2026-09-20"
  end

  test "a binary sitemap body renders the discovered urls" do
    RecordingStudio::SiteIndexFinder.configuration.transport = binary_site

    with_public_dns do
      get root_path, params: { url: "https://example.com" }
    end

    assert_response :success
    assert_includes response.body, "https://example.com/a"
    assert_includes response.body, "Found"
  end

  test "a restricted sitemap shows the status" do
    RecordingStudio::SiteIndexFinder.configuration.transport = restricted_site

    with_public_dns do
      get root_path, params: { url: "https://example.com" }
    end

    assert_response :success
    assert_includes response.body, "forbidden"
    assert_includes response.body, "The sitemap is restricted"
    assert_includes response.body, "403"
  end

  test "an unsafe url shows the rejection" do
    get root_path, params: { url: "http://127.0.0.1" }

    assert_response :success
    assert_includes response.body, "The URL is not allowed"
    refute_includes response.body, "Resolved site URL"
  end

  private

  def with_public_dns
    original = Resolv.method(:getaddresses)
    Resolv.define_singleton_method(:getaddresses) { |_host| [PUBLIC_IP] }
    yield
  ensure
    Resolv.define_singleton_method(:getaddresses) { |host| original.call(host) }
  end

  def finder_user
    User.find_or_create_by!(email: "site-index-finder@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
  end

  def prepare_workspace
    workspace = Workspace.find_or_create_by!(name: "Site Index Workspace")
    RecordingStudio.root_recording_for(workspace)
  end

  def binary_site
    xml = "\xEF\xBB\xBF".b + "<urlset><url><loc>https://example.com/a</loc></url></urlset>".b
    map = {
      "https://example.com/" => { status: 200, body: "home" },
      "https://example.com/robots.txt" => { status: 200, body: "Sitemap: https://example.com/sitemap.xml".b },
      "https://example.com/sitemap.xml" => {
        status: 200,
        body: xml,
        headers: { "content-type" => "application/xml" }
      }
    }

    lambda do |hop|
      spec = map.fetch(hop.fetch(:url))
      {
        status: spec[:status],
        body: spec[:body],
        headers: spec[:headers] || {},
        location: nil,
        address: hop.fetch(:address)
      }
    end
  end

  def restricted_site
    lambda do |hop|
      url = hop.fetch(:url)
      status = if url.end_with?("/sitemap.xml")
                 403
               elsif url.end_with?(".xml")
                 404
               else
                 200
               end
      body = url.end_with?("/robots.txt") ? "Sitemap: https://example.com/sitemap.xml" : "home"
      {
        status: status,
        body: body,
        headers: {},
        location: nil,
        address: hop.fetch(:address)
      }
    end
  end

  def scripted_site
    map = {
      "https://example.com/" => { status: 200, body: "home" },
      "https://example.com/robots.txt" => { status: 200, body: "Sitemap: https://example.com/sitemap.xml" },
      "https://example.com/sitemap.xml" => {
        status: 200,
        body: "<urlset><url><loc>https://example.com/a</loc><lastmod>2026-09-20</lastmod></url></urlset>",
        headers: { "content-type" => "application/xml" }
      }
    }

    lambda do |hop|
      spec = map.fetch(hop.fetch(:url))
      {
        status: spec[:status],
        body: spec[:body],
        headers: spec[:headers] || {},
        location: nil,
        address: hop.fetch(:address)
      }
    end
  end
end
