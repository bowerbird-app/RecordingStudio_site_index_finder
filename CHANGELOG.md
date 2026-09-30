# Changelog

## 0.1.0

Site Index Finder discovers a public website's sitemap files and returns the URLs they list.

`RecordingStudio::SiteIndexFinder.find` reads `robots.txt`, follows sitemap indexes, and returns a result object. The gem does not persist that result.

Each error includes the HTTP status when the failure came from a response. A sitemap that returns 401 or 403 is recorded as `forbidden`.
