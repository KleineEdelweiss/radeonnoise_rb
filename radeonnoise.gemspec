# frozen_string_literal: true
require_relative "lib/radeonnoise/version.rb"

Gem::Specification.new do |spec|
  spec.name = "radeonnoise"
  spec.version = RadeonNoise::VERSION
  spec.summary = "Linux AMDGPU controller in Ruby"
  spec.description = <<~DESC
    Ruby module to provide access to Linux's AMDGPU
    driver API from Ruby scripts.
    
    + Control operations require `root` access.
  DESC
  spec.authors = ["Edelweiss"]
  
  spec.homepage = "https://github.com/KleineEdelweiss/radeonnoise_rb"
  spec.licenses = ["LGPL-3.0"]
  spec.metadata = {
    "homepage_uri"        => spec.homepage,
    "source_code_uri"     => "https://github.com/KleineEdelweiss/radeonnoise_rb",
    #"documentation_uri"   => "",
    #"changelog_uri"       => "https://github.com/KleineEdelweiss/radeonnoise_rb/blob/master/CHANGELOG.md",
    "bug_tracker_uri"     => "https://github.com/KleineEdelweiss/radeonnoise_rb/issues"
  }
  
  spec.files = Dir.glob("lib/**/*")
  
  spec.extra_rdoc_files = Dir["README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.rdoc_options += [
    "--title", "RadeonNoise RB -- Linux AMDGPU Controller",
    "--main", "README.md",
    "--line-numbers",
    "--inline-source",
    "--quiet"
  ]
  
  spec.required_ruby_version = ">= 2.7.0"
end