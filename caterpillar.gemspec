# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "caterpillar/version"

Gem::Specification.new do |gem|
  gem.name        = "caterpillar"
  gem.version     = Caterpillar::VERSION
  gem.authors     = ["Julio Santos"]
  gem.email       = ["julio@morgane.com"]
  gem.homepage    = ""
  gem.summary     = "Scrape Amazon Seller Central"
  gem.description = "Scrape Amazon Seller Central"

  gem.rubyforge_project = "caterpillar"

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "mechanize"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "mocha"
  gem.add_development_dependency "vcr"
  gem.add_development_dependency "fakeweb"
  gem.add_development_dependency "rcov", '0.9.11'
end
