# frozen_string_literal: true

require_relative "lib/recording_studio_site_index_finder/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_site_index_finder"
  spec.version     = RecordingStudio::SiteIndexFinder::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_site_index_finder"
  spec.summary     = "Find the published sitemap index of a public website"
  spec.description = "Recording Studio addon that discovers a public website's robots.txt and sitemap " \
                     "files and returns the URLs those sitemaps expose."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_site_index_finder"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_site_index_finder/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "rexml"
end
