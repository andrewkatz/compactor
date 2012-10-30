# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "caterpillar/version"

Gem::Specification.new do |s|
  s.name        = "caterpillar"
  s.version     = Caterpillar::VERSION
  s.authors     = ["Julio Santos"]
  s.email       = ["julio@morgane.com"]
  s.homepage    = ""
  s.summary     = "Scrape Amazon Seller Central"
  s.description = "Scrape Amazon Seller Central"

  s.rubyforge_project = "caterpillar"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "mechanize"

  s.add_development_dependency "mocha"
  s.add_development_dependency "vcr"
  s.add_development_dependency "fakeweb"
  s.add_development_dependency "rcov", '0.9.11'
end
