require "bundler/setup"

require "test/unit"
require "vcr"
require "mechanize"
require "compactor"
require "mocha"

VCR.configure do |vcr|
  vcr.cassette_library_dir = 'test/fixtures/vcr_cassettes'
  vcr.hook_into :fakeweb
end
FakeWeb.allow_net_connect = false

class Compactor::Amazon::ReportScraper
  def slowdown_like_a_human(count)
    # do not slowdown
  end
end
