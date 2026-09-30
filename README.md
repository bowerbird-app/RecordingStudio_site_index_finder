# Site Index Finder

Recording Studio Site Index Finder discovers the sitemap files a public website publishes and returns the URLs those files list.

```ruby
result = RecordingStudio::SiteIndexFinder.find("https://example.com")
result.site_url
result.sitemaps
result.urls
result.url_count
result.errors
result.to_h
```

## What this gem does

Give it a website URL. It resolves that URL to a public origin, reads `robots.txt`, and follows the sitemap files the site declares. When `robots.txt` has no usable sitemap, it tries three conventional paths.

The result is a value object. Another gem can store that object later. This gem does not store it.

## What this gem does not do

This gem is a finder. It does not crawl HTML, classify pages, extract articles, build search indexes, match press coverage, or call an LLM.

It also does not know about Publications or Channels. Pass a site URL. Read the result.

## Our sitemap and their sitemap

Recording Studio Sitemaps writes the sitemap for an app we run.

```text
RecordingStudio Sitemaps
our records
then our sitemap.xml
```

Site Index Finder reads the sitemap another site already published.

```text
RecordingStudio Site Index Finder
external website
then discover published sitemap infrastructure
then return URLs
```

`SiteIndexFinder` discovers. A `SiteIndex` record, if you add one later, belongs in the gem that stores it.

## Installation

Add the gem to the host app. `recording_studio` is not on RubyGems, so the host pins it from GitHub the same way this repo does.

```ruby
gem "recording_studio_site_index_finder", github: "bowerbird-app/RecordingStudio_site_index_finder"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
```

Then install the engine.

```bash
bin/rails generate recording_studio_site_index_finder:install
```

The generator mounts the engine, copies an initializer, and can add a YAML file. The finder does not add database tables.

The dummy app in this repo also pins FlatPack `v0.1.177`, Recording Studio Accessible `v0.9.1`, and Recording Studio Root Switchable `v0.5.0`.

## Configuration

```ruby
RecordingStudio::SiteIndexFinder.configure do |config|
  config.open_timeout = 5
  config.read_timeout = 10
  config.max_redirects = 5
  config.max_response_bytes = 5_000_000
  config.max_sitemap_depth = 4
  config.max_sitemap_count = 50
  config.instrumentation_enabled = true
end
```

Those are the defaults. The write timeout stays at 5 seconds. The user agent is `RecordingStudioSiteIndexFinder/#{version}`.

Depth `0` is the first sitemap file. A child sitemap is one level deeper. The count limit includes every sitemap file the finder fetches, both indexes and URL sets.

You can also set the same keys in `config/recording_studio_site_index_finder.yml` or `config.x.recording_studio_site_index_finder`. An initializer runs after those and wins.

## Public API

```ruby
result = RecordingStudio::SiteIndexFinder.find("https://example.com/article/example")
```

Accepted inputs include a bare host, a `www` host, an origin, and a page URL. The finder reduces the input to an origin and follows public redirects.

```text
example.com
www.example.com
https://example.com
https://example.com/article/example
```

`find` raises `RecordingStudio::SiteIndexFinder::InvalidUrlError` when the input is blank or not HTTP or HTTPS. It raises `RecordingStudio::SiteIndexFinder::UnsafeUrlError` when the input, or a redirect of that input, points at a blocked host or address.

A missing sitemap, a broken child file, or a site that cannot be reached does not raise. Those outcomes come back on the result.

## Result object

`result.site_url` is the resolved origin, with a trailing slash.

`result.sitemaps` is an array of `Sitemap` objects. Each one has `url` and `type`, either `:index` or `:urlset`.

`result.urls` is an array of `IndexedUrl` objects. Each one has `url` and `last_modified_at`. `last_modified_at` is the publisher's string, or `nil` when the sitemap omits `lastmod`.

`result.url_count` is `result.urls.size`.

`result.errors` is an array of `FindingError` objects. Each one has `code`, `message`, and `url`.

`result.status` is `:found`, `:partial`, `:empty`, or `:failed`.

`result.to_h` uses string keys. `JSON.generate(result.to_h)` works. Sitemap type and error code are strings in that hash.

## Sitemap discovery

The finder does this in order.

1. Normalize the input to an HTTP or HTTPS origin.
2. `GET` that origin and follow redirects. The final origin is `site_url`.
3. `GET {site_url}robots.txt`.
4. Read every `Sitemap:` line. Blank lines and `#` comments are ignored. The match is case insensitive.
5. Fetch those sitemap URLs. When at least one parses, stop looking for conventional paths.
6. When none parse, try `/sitemap.xml`, then `/sitemap_index.xml`, then `/sitemap-index.xml`. Stop at the first one that parses.

A sitemap index lists more sitemap URLs. The finder fetches those, including an index nested inside another index. Child addresses are resolved against the parent sitemap URL.

The walk is a queue. A sitemap URL is fetched once. A page URL is returned once, and the first `lastmod` wins. Fragments are removed. Paths, query strings, schemes, and subdomains stay as the publisher wrote them.

## Supported sitemap types

URL set:

```xml
<urlset>
  <url>
    <loc>https://example.com/article-one</loc>
    <lastmod>2026-09-20</lastmod>
  </url>
</urlset>
```

Sitemap index:

```xml
<sitemapindex>
  <sitemap>
    <loc>https://example.com/posts.xml</loc>
  </sitemap>
</sitemapindex>
```

The default sitemap namespace is accepted. `loc` is required for a page entry. `lastmod` is optional. Other sitemap tags are ignored.

A gzip body is inflated when the bytes are gzip. Net::HTTP already inflates `Content-Encoding: gzip`, so a decoded body is left as it arrived. Sitemap and robots bodies are read as UTF-8, including bodies that arrived as binary. A leading byte-order mark is removed.

## Security

Every request is checked before the socket opens.

- HTTP and HTTPS only
- No URL userinfo
- Localhost and `*.localhost` rejected
- Private, loopback, link-local, and documentation ranges rejected
- Cloud metadata addresses rejected, including `169.254.169.254`, `metadata.google.internal`, and `metadata.goog`
- DNS answers are checked. One private address rejects the host
- The connection uses the address from that check
- Each redirect is checked again
- TLS certificates are verified
- Open, read, and write timeouts apply to each hop
- Response bodies are capped
- Redirects are capped

Web Reader does not expose a public fetch for `robots.txt` or sitemap XML. `RecordingStudio::WebReader.read` accepts HTML pages. This gem keeps its own fetch path and copies those checks. It does not call Web Reader internals.

Web Search is not used. A `site:` query is not a sitemap.

## Failure behaviour

| Situation | Result |
| --- | --- |
| Unsafe or invalid input | `find` raises |
| `robots.txt` is missing | Conventional sitemap paths are tried |
| `robots.txt` has no `Sitemap` lines | Conventional sitemap paths are tried |
| `robots.txt` is HTML or another non-robots body | An error is recorded and conventional paths are tried |
| One child sitemap is malformed, missing, or too large | That error is recorded and the other files are kept |
| A child URL points at a private address | That error is recorded and the walk continues |
| The sitemap graph loops | Each sitemap URL is fetched once |
| The depth or count limit is hit | One limit error is recorded and the walk stops |
| No sitemap exists | A result with zero URLs and zero errors |

## Instrumentation

Each call emits `find.recording_studio_site_index_finder` when instrumentation is enabled.

```ruby
{
  schema_version: 1,
  host: "example.com",
  success: true,
  request_count: 3,
  sitemap_count: 1,
  url_count: 2,
  error_type: nil,
  duration_ms: 40
}
```

`success` is true when `find` returns a result, including a result that lists child errors. `error_type` is the first error code, or the exception class name when `find` raises. `host` is the hostname only.

The event does not include the page URL, XML, `robots.txt`, headers, or response bodies.

## Dummy app

`test/dummy` is a host app for checking the gem. Sign in at `/users/sign_in` with `admin@admin.com` and `Password`. The home page takes a site URL and runs `RecordingStudio::SiteIndexFinder.find`. It shows the supplied URL, the resolved origin, the status, the sitemap files, the URL count, the discovered URLs, `lastmod` when present, and the errors.

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

## Tests

```bash
bundle exec rake test
```

The finder tests stub DNS and HTTP. They cover one sitemap, several `Sitemap` lines, indexes, nested indexes, duplicate files, duplicate URLs, a missing or empty or unreadable `robots.txt`, bad XML, a missing sitemap, a site with no sitemap, redirects, unsafe URLs, loops, oversized bodies, and the depth and count limits.
