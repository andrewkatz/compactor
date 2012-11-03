require File.dirname(__FILE__) + '/test_helper'

class MechanizeExtensionsTest < Test::Unit::TestCase
  def test_should_raise_exception_if_selector_cannot_be_found
    email    = "far@far.away"
    password = "password"

    mechanize = Mechanize.new
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/reports_to_request") do
      mechanize.get "https://sellercentral.amazon.com/gp/homepage.html"
      assert_raises Nokogiri::MissingElement do
        mechanize.page.search! "#foo"
      end
    end
  end
end
