# frozen_string_literal: true

require "test_helper"
require "json"
require "zlib"
require "openssl"

class SiteIndexFinderTest < Minitest::Test
  PUBLIC_IP = "93.184.216.34"
  EVENT = "find.recording_studio_site_index_finder"

  def setup
    @original = RecordingStudio::SiteIndexFinder.instance_variable_get(:@configuration)
    RecordingStudio::SiteIndexFinder.instance_variable_set(
      :@configuration,
      RecordingStudio::SiteIndexFinder::Configuration.new
    )
  end

  def teardown
    RecordingStudio::SiteIndexFinder.instance_variable_set(:@configuration, @original)
  end

  def test_robots_with_one_sitemap_returns_both_urls
    body = urlset("https://example.com/a", "https://example.com/b")
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(body)
    )

    assert_equal "https://example.com/", result.site_url
    assert_equal [:urlset], result.sitemaps.map(&:type)
    assert_equal ["https://example.com/a", "https://example.com/b"], result.urls.map(&:url)
    assert_equal 2, result.url_count
    assert_empty result.errors
    assert_equal :found, result.status
  end

  def test_robots_with_multiple_sitemap_declarations_keeps_every_url
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text(<<~ROBOTS),
        Sitemap: https://example.com/posts.xml
        Sitemap: https://example.com/pages.xml
      ROBOTS
      "https://example.com/posts.xml" => xml(urlset("https://example.com/post")),
      "https://example.com/pages.xml" => xml(urlset("https://example.com/page"))
    )

    assert_equal ["https://example.com/post", "https://example.com/page"], result.urls.map(&:url)
    assert_equal 2, result.sitemaps.size
  end

  def test_sitemap_index_follows_child_urlsets
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(index("https://example.com/posts.xml", "https://example.com/pages.xml")),
      "https://example.com/posts.xml" => xml(urlset("https://example.com/post")),
      "https://example.com/pages.xml" => xml(urlset("https://example.com/page"))
    )

    types = result.sitemaps.map { |sitemap| sitemap.type.to_s }
    assert_equal %w[index urlset urlset], types
    assert_equal ["https://example.com/post", "https://example.com/page"], result.urls.map(&:url)
  end

  def test_nested_sitemap_indexes_are_followed
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(index("https://example.com/nested.xml")),
      "https://example.com/nested.xml" => xml(index("https://example.com/posts.xml")),
      "https://example.com/posts.xml" => xml(urlset("https://example.com/post"))
    )

    assert_equal ["https://example.com/post"], result.urls.map(&:url)
    assert_equal 3, result.sitemaps.size
  end

  def test_duplicate_sitemap_references_are_fetched_once
    calls = []
    result = find_site(
      {
        "https://example.com/" => page,
        "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
        "https://example.com/sitemap.xml" => xml(index("https://example.com/posts.xml", "https://example.com/posts.xml")),
        "https://example.com/posts.xml" => xml(urlset("https://example.com/post"))
      },
      calls: calls
    )

    assert_equal ["https://example.com/post"], result.urls.map(&:url)
    assert_equal 1, calls.count("https://example.com/posts.xml")
  end

  def test_duplicate_page_urls_are_returned_once_and_keep_the_first_lastmod
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(index("https://example.com/one.xml", "https://example.com/two.xml")),
      "https://example.com/one.xml" => xml(urlset_with_lastmod("https://example.com/a", "2026-09-20")),
      "https://example.com/two.xml" => xml(urlset_with_lastmod("https://example.com/a#section", "2020-01-01"))
    )

    assert_equal 1, result.url_count
    assert_equal "https://example.com/a", result.urls.first.url
    assert_equal "2026-09-20", result.urls.first.last_modified_at
  end

  def test_missing_robots_continues_to_the_conventional_sitemap
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => { status: 404, body: "" },
      "https://example.com/sitemap.xml" => xml(urlset("https://example.com/a"))
    )

    assert_equal ["https://example.com/a"], result.urls.map(&:url)
    assert_empty result.errors
  end

  def test_robots_without_sitemap_entries_uses_a_conventional_path
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("User-agent: *\nDisallow: /private"),
      "https://example.com/sitemap.xml" => xml(urlset("https://example.com/a"))
    )

    assert_equal ["https://example.com/a"], result.urls.map(&:url)
  end

  def test_malformed_robots_records_an_error_and_continues
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("<html><body>not robots</body></html>"),
      "https://example.com/sitemap.xml" => xml(urlset("https://example.com/a"))
    )

    assert_equal ["https://example.com/a"], result.urls.map(&:url)
    assert_equal :robots, result.errors.first.code
    assert_equal :partial, result.status
  end

  def test_malformed_child_xml_does_not_drop_the_other_sitemap
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(index("https://example.com/bad.xml", "https://example.com/good.xml")),
      "https://example.com/bad.xml" => xml("<urlset><url></not-xml>"),
      "https://example.com/good.xml" => xml(urlset("https://example.com/good"))
    )

    assert_equal ["https://example.com/good"], result.urls.map(&:url)
    assert_equal :malformed_xml, result.errors.first.code
    assert_equal "https://example.com/bad.xml", result.errors.first.url
  end

  def test_declared_sitemap_404_continues_to_a_conventional_sitemap
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/missing.xml"),
      "https://example.com/missing.xml" => { status: 404, body: "" },
      "https://example.com/sitemap.xml" => xml(urlset("https://example.com/a"))
    )

    assert_equal ["https://example.com/a"], result.urls.map(&:url)
    assert_equal :missing, result.errors.first.code
  end

  def test_site_with_no_sitemap_returns_an_empty_result
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => { status: 404, body: "" },
      "https://example.com/sitemap.xml" => { status: 404, body: "" },
      "https://example.com/sitemap_index.xml" => { status: 404, body: "" },
      "https://example.com/sitemap-index.xml" => { status: 404, body: "" }
    )

    assert_equal "https://example.com/", result.site_url
    assert_empty result.sitemaps
    assert_equal 0, result.url_count
    assert_empty result.errors
    assert_equal :empty, result.status
  end

  def test_origin_redirect_is_followed_before_robots
    result = find_site(
      "https://example.com/" => { status: 301, body: "", location: "https://www.example.com/" },
      "https://www.example.com/" => page,
      "https://www.example.com/robots.txt" => text("Sitemap: https://www.example.com/sitemap.xml"),
      "https://www.example.com/sitemap.xml" => xml(urlset("https://www.example.com/a"))
    )

    assert_equal "https://www.example.com/", result.site_url
    assert_equal ["https://www.example.com/a"], result.urls.map(&:url)
  end

  def test_bare_host_and_article_url_resolve_to_the_https_origin
    pages = {
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(urlset("https://example.com/a"))
    }

    from_host = find_site(pages, input: "example.com")
    from_article = find_site(pages, input: "https://example.com/article/example")

    assert_equal "https://example.com/", from_host.site_url
    assert_equal "https://example.com/", from_article.site_url
    assert_equal ["https://example.com/a"], from_article.urls.map(&:url)
  end

  def test_page_urls_keep_query_scheme_and_subdomain
    loc = "http://blog.example.com/a?b=1&c=2"
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(urlset(loc.gsub("&", "&amp;")))
    )

    assert_equal loc, result.urls.first.url
  end

  def test_lastmod_is_optional
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(urlset("https://example.com/a"))
    )

    assert_nil result.urls.first.last_modified_at
  end

  def test_decoded_body_with_gzip_header_is_read
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => {
        status: 200,
        body: urlset("https://example.com/a"),
        headers: { "content-encoding" => "gzip", "content-type" => "application/xml" }
      }
    )

    assert_equal ["https://example.com/a"], result.urls.map(&:url)
  end

  def test_gzip_sitemap_is_read
    xml_body = urlset("https://example.com/a")
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml.gz"),
      "https://example.com/sitemap.xml.gz" => {
        status: 200,
        body: Zlib.gzip(xml_body),
        headers: { "content-type" => "application/gzip" }
      }
    )

    assert_equal ["https://example.com/a"], result.urls.map(&:url)
  end

  def test_namespaced_sitemap_xml_is_read
    xml_body = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>https://example.com/a</loc><lastmod>2026-09-20</lastmod></url>
      </urlset>
    XML
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(xml_body)
    )

    assert_equal "https://example.com/a", result.urls.first.url
    assert_equal "2026-09-20", result.urls.first.last_modified_at
  end

  def test_unsafe_urls_are_rejected
    [
      "http://localhost/admin",
      "http://127.0.0.1/",
      "http://10.1.2.3/",
      "http://192.168.1.9/",
      "http://172.16.0.4/",
      "http://169.254.169.254/",
      "http://user:pass@example.com/",
      "http://metadata.google.internal/",
      "http://2130706433/"
    ].each do |url|
      assert_raises RecordingStudio::SiteIndexFinder::UnsafeUrlError, url do
        RecordingStudio::SiteIndexFinder.find(url)
      end
    end
  end

  def test_private_dns_answer_is_rejected
    Resolv.stub(:getaddresses, ->(_host) { ["127.0.0.1"] }) do
      assert_raises RecordingStudio::SiteIndexFinder::UnsafeUrlError do
        RecordingStudio::SiteIndexFinder.find("https://example.com")
      end
    end
  end

  def test_redirect_to_a_metadata_address_is_rejected
    calls = []
    error = assert_raises RecordingStudio::SiteIndexFinder::UnsafeUrlError do
      find_site(
        { "https://example.com/" => { status: 302, body: "", location: "http://169.254.169.254/latest" } },
        calls: calls
      )
    end

    assert_equal "The URL is not allowed", error.message
    assert_equal ["https://example.com/"], calls
  end

  def test_sitemap_loop_stops
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(index("https://example.com/sitemap.xml"))
    )

    assert_equal 1, result.sitemaps.size
    assert_empty result.urls
    assert_empty result.errors
  end

  def test_oversized_sitemap_is_reported_and_other_files_continue
    RecordingStudio::SiteIndexFinder.configuration.max_response_bytes = 400
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(index("https://example.com/big.xml", "https://example.com/small.xml")),
      "https://example.com/big.xml" => xml("x" * 2_000),
      "https://example.com/small.xml" => xml(urlset("https://example.com/a"))
    )

    assert_equal ["https://example.com/a"], result.urls.map(&:url)
    assert_equal :too_large, result.errors.first.code
  end

  def test_sitemap_count_limit_stops_the_graph
    RecordingStudio::SiteIndexFinder.configuration.max_sitemap_count = 2
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(
        index("https://example.com/one.xml", "https://example.com/two.xml", "https://example.com/three.xml")
      ),
      "https://example.com/one.xml" => xml(urlset("https://example.com/one")),
      "https://example.com/two.xml" => xml(urlset("https://example.com/two")),
      "https://example.com/three.xml" => xml(urlset("https://example.com/three"))
    )

    assert_equal ["https://example.com/one"], result.urls.map(&:url)
    assert_equal :limit, result.errors.first.code
    assert_equal 2, result.sitemaps.size
  end

  def test_sitemap_depth_limit_stops_nested_indexes
    RecordingStudio::SiteIndexFinder.configuration.max_sitemap_depth = 0
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(index("https://example.com/posts.xml")),
      "https://example.com/posts.xml" => xml(urlset("https://example.com/post"))
    )

    assert_empty result.urls
    assert_equal :depth, result.errors.first.code
    assert_equal 1, result.sitemaps.size
  end

  def test_child_sitemap_on_a_private_address_does_not_drop_other_urls
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(index("http://127.0.0.1/secret.xml", "https://example.com/posts.xml")),
      "https://example.com/posts.xml" => xml(urlset("https://example.com/post"))
    )

    assert_equal ["https://example.com/post"], result.urls.map(&:url)
    assert_equal :unsafe, result.errors.first.code
  end

  def test_to_h_is_json_safe
    result = find_site(
      "https://example.com/" => page,
      "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
      "https://example.com/sitemap.xml" => xml(urlset_with_lastmod("https://example.com/a", "2026-09-20"))
    )
    payload = JSON.parse(JSON.generate(result.to_h))

    assert_equal "https://example.com/", payload.fetch("site_url")
    assert_equal "urlset", payload.fetch("sitemaps").first.fetch("type")
    assert_equal "2026-09-20", payload.fetch("urls").first.fetch("last_modified_at")
    assert_equal 1, payload.fetch("url_count")
    assert_equal [], payload.fetch("errors")
  end

  def test_notification_carries_safe_metadata_only
    events = []
    callback = lambda do |event|
      events << event
    end

    ActiveSupport::Notifications.subscribed(callback, EVENT) do
      find_site(
        "https://example.com/" => page,
        "https://example.com/robots.txt" => text("Sitemap: https://example.com/sitemap.xml"),
        "https://example.com/sitemap.xml" => xml(urlset("https://example.com/a"))
      )
    end

    payload = events.last.payload
    assert_equal "example.com", payload[:host]
    assert_equal true, payload[:success]
    assert_equal 3, payload[:request_count]
    assert_equal 1, payload[:sitemap_count]
    assert_equal 1, payload[:url_count]
    assert_nil payload[:error_type]
    assert_kind_of Integer, payload[:duration_ms]
    assert_equal 1, payload[:schema_version]
    refute_includes payload.values.map(&:to_s).join, "<urlset"
    refute_includes payload.keys, :body
  end

  def test_rejected_url_notification_names_the_error_and_omits_the_url
    events = []
    ActiveSupport::Notifications.subscribed(->(event) { events << event }, EVENT) do
      assert_raises RecordingStudio::SiteIndexFinder::UnsafeUrlError do
        RecordingStudio::SiteIndexFinder.find("http://127.0.0.1/secret")
      end
    end

    payload = events.last.payload
    assert_equal false, payload[:success]
    assert_equal "RecordingStudio::SiteIndexFinder::UnsafeUrlError", payload[:error_type]
    assert_equal "127.0.0.1", payload[:host]
    refute_includes payload.values.map(&:to_s).join, "/secret"
  end

  def test_exchange_pins_the_address_verifies_tls_and_rejects_a_declared_oversize_body
    response = FakeHttpResponse.new(code: "200", headers: { "content-length" => "9000000" }, chunks: ["tiny"])
    http = FakeHttp.new(response)
    hop = {
      url: "https://example.com/sitemap.xml",
      host: "example.com",
      port: 443,
      address: PUBLIC_IP,
      https: true,
      user_agent: "test",
      max_bytes: 100,
      timeouts: { open: 1, read: 1, write: 1 }
    }

    Net::HTTP.stub(:new, ->(*) { http }) do
      assert_raises RecordingStudio::SiteIndexFinder::ResponseTooLargeError do
        RecordingStudio::SiteIndexFinder::Exchange.call(hop)
      end
    end

    assert_equal PUBLIC_IP, http.ipaddr
    assert_equal true, http.use_ssl
    assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
    assert_equal false, response.body_read
  end

  private

  def find_site(map = nil, input: "https://example.com", calls: nil, **extra)
    map = extra if map.nil?
    RecordingStudio::SiteIndexFinder.configuration.transport = scripted(map, calls)
    with_public_dns { RecordingStudio::SiteIndexFinder.find(input) }
  end

  def scripted(map, calls)
    lambda do |hop|
      url = hop.fetch(:url)
      calls << url if calls
      spec = map.fetch(url)
      {
        status: spec[:status] || 200,
        body: spec[:body] || "",
        headers: spec[:headers] || {},
        location: spec[:location],
        address: hop.fetch(:address)
      }
    end
  end

  def with_public_dns(&)
    Resolv.stub(:getaddresses, ->(_host) { [PUBLIC_IP] }, &)
  end

  def page
    { status: 200, body: "home" }
  end

  def text(body)
    { status: 200, body: body }
  end

  def xml(body)
    { status: 200, body: body, headers: { "content-type" => "application/xml" } }
  end

  def urlset(*locs)
    urls = locs.map { |loc| "<url><loc>#{loc}</loc></url>" }.join
    "<urlset>#{urls}</urlset>"
  end

  def urlset_with_lastmod(loc, lastmod)
    "<urlset><url><loc>#{loc}</loc><lastmod>#{lastmod}</lastmod></url></urlset>"
  end

  def index(*locs)
    items = locs.map { |loc| "<sitemap><loc>#{loc}</loc></sitemap>" }.join
    "<sitemapindex>#{items}</sitemapindex>"
  end

  class FakeHttp
    attr_accessor :ipaddr, :use_ssl, :verify_mode

    def initialize(response)
      @response = response
    end

    def open_timeout=(_value); end
    def read_timeout=(_value); end
    def write_timeout=(_value); end
    def max_retries=(_value); end

    def request(_request)
      yield @response
    end
  end

  class FakeHttpResponse
    attr_reader :code, :body_read

    def initialize(code:, headers:, chunks:)
      @code = code
      @headers = headers
      @chunks = chunks
      @body_read = false
    end

    def each_header(&)
      @headers.each(&)
    end

    def read_body(&)
      @body_read = true
      @chunks.each(&)
    end
  end
end
