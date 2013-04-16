require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../lib/compactor')

class ScraperTest < Test::Unit::TestCase
  def setup
    Compactor::Amazon::XmlParser.any_instance.stubs(:valid?).returns(true)
  end

  def test_should_not_find_elements_that_do_not_exist
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/reports_to_request") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      mechanize = scraper.instance_variable_get("@mechanize")
      element = scraper.send(:wait_for_element, 1) do
        mechanize.page.search(".something-that-does-not-exist")
      end
      assert_nil element
    end
  end

  def test_should_find_elements_that_do_exist
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/reports_to_request") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      mechanize = scraper.instance_variable_get("@mechanize")
      element = scraper.send(:wait_for_element, 1) do
        mechanize.page.forms
      end
      assert Mechanize::Form === element[0]
    end
  end

  def test_should_raise_error_if_cannot_find_login_form
    Mechanize::Form.any_instance.expects(:[]).with("email").returns(nil)
    Compactor::Amazon::ReportScraper.any_instance.stubs(:default_number_of_attempts).returns(1)
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/reports_to_request") do
      assert_raises Compactor::Amazon::LoginFormNotFoundError do
        Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      end
    end
  end

  def test_should_raise_error_with_bad_login
    VCR.use_cassette("AmazonReportScraper/with_bad_login/raise_error") do
      assert_raises Compactor::Amazon::AuthenticationError do
        Compactor::Amazon::ReportScraper.new(:email => "bad@email.here", :password => "invalid")
      end
    end
  end

  def test_should_be_xml_if_button_label_is_Download_XML
    assert_equal :xml, Compactor::Amazon::ReportScraper.report_type("Download XML")
  end

  def test_should_be_xml_if_button_label_is_Flat_File
    assert_equal :tsv, Compactor::Amazon::ReportScraper.report_type("Download Flat File")
  end

  def test_should_be_xml_if_button_label_is_Flat_File_V2
    assert_equal :tsv2, Compactor::Amazon::ReportScraper.report_type("Download Flat File V2")
  end

  def test_should_raise_error_if_type_is_not_identifiable_from_the_button_label
    assert_raises Compactor::Amazon::UnknownReportType do
      Compactor::Amazon::ReportScraper.report_type("Download PDF")
    end
  end

  def test_should_be_able_to_get_buyer_name_and_shipping_address_for_orders
    VCR.use_cassette("AmazonReportScraper/with_good_login/get_orders") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      orders = scraper.get_orders(["103-4328675-4697061"])

      assert_equal({
        "103-4328675-4697061" => {
          "BuyerName"       => "Jared Smith",
          "ShippingAddress" => {
            "street"     => "813 FARLEY ST",
            "city"       => "MOUNTAIN VIEW",
            "state"      => "CA",
            "postalcode" => "94043-3013"
          }
        }
      }, orders)
    end
  end

  def test_should_support_addresses_where_the_street_address_line_does_not_start_with_a_number
    VCR.use_cassette("AmazonReportScraper/with_good_login/shipping_address_not_starting_with_number") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      orders = scraper.get_orders(["105-1753716-0471420"])

      assert_equal({
        "105-1753716-0471420" => {
          "BuyerName"       => "Lisa M Strand",
          "ShippingAddress" => {
            "street"     => "W190S6321 Preston Ln",
            "city"       => "Muskego",
            "state"      => "WI",
            "postalcode" => "53150-8512"
          }
        }
      }, orders)
    end
  end

  def test_should_handle_large_reports
    VCR.use_cassette("AmazonReportScraper/with_good_login/get_orders_big") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      scraper.select_marketplace("ATVPDKIKX0DER")
      assert_nothing_raised do
        scraper.reports('2012-05-01', '2012-05-08')
      end
    end
  end

  def test_should_find_no_reports_if_none_exist
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/no_reports_to_request") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      reports = scraper.reports("1/1/2012", "3/20/2012")

      assert_equal( true, reports.any? { |type, reports| !reports.empty? } )
    end
  end

  def test_should_find_reports_with_good_login
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/reports_to_request") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      reports = scraper.reports("12/28/2011", "12/30/2011")

      assert_equal( true, reports.any? { |type, reports| !reports.empty? } )
    end
  end

  def test_should_find_reports_in_more_than_on_page
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/multiple_pages") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      reports = scraper.reports("3/1/2012", "3/21/2012")

      assert_equal( true, reports.any? { |type, reports| !reports.empty? } )
    end
  end

  def test_should_find_no_reports_if_not_in_date_range
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/no_reports") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      reports = scraper.reports("1/1/2011", "1/8/2011")

      assert_equal( true, reports.all? { |type, reports| reports.empty? } )
    end
  end

  def test_should_raise_error_if_nothing_to_request
    VCR.use_cassette("AmazonReportScraper/with_good_login/find_reports/no_reports_to_request") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      Compactor::Amazon::ReportScraper.stubs(:report_type).raises(Compactor::Amazon::UnknownReportType)

      assert_raises Compactor::Amazon::UnknownReportType do
        scraper.reports("1/1/2012", "3/20/2012")
      end
    end
  end

  def test_should_return_balance
    VCR.use_cassette("AmazonReportScraper/with_good_login/get_balance") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      assert_equal(26.14, scraper.get_balance)
    end
  end

  def test_should_list_marketplaces_if_single
    VCR.use_cassette("AmazonReportScraper/with_good_login/with_single_marketplaces/get_marketplaces") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      expected_marketplaces = [["www.amazon.com", nil]]
      assert_equal expected_marketplaces, scraper.get_marketplaces.sort
    end
  end

  def test_should_list_marketplaces_if_several
    VCR.use_cassette("AmazonReportScraper/with_good_login/with_multiple_marketplaces/get_marketplaces") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      expected_marketplaces = [["Your Checkout Website", "AZ4B0ZS3LGLX"], ["Your Checkout Website (Sandbox)", "A2SMC08ZTYKXKX"], ["www.amazon.com", "ATVPDKIKX0DER"]]
      assert_equal expected_marketplaces, scraper.get_marketplaces.sort
    end
  end

  def test_should_find_reports_for_current_marketplace
    VCR.use_cassette("AmazonReportScraper/with_good_login/with_multiple_marketplaces/find_reports/reports_to_request") do
      scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      scraper.select_marketplace("AZ4B0ZS3LGLX")
      reports_1 = scraper.reports("4/1/2012", "4/5/2012")
      assert_equal(719, ( reports_1[:xml].first =~ /<AmazonOrderID>.*<\/AmazonOrderID>/ ) )
      assert_equal("<AmazonOrderID>105-3439340-2677033</AmazonOrderID>", reports_1[:xml].first[719,50])
      scraper.select_marketplace("ATVPDKIKX0DER")
      reports_2 = scraper.reports("4/1/2012", "4/5/2012")
      assert_equal(720, ( reports_2[:xml].first =~ /<AmazonOrderID>.*<\/AmazonOrderID>/ ) )
      assert_equal("<AmazonOrderID>105-3231361-4893023</AmazonOrderID>", reports_2[:xml].first[720,50])
    end
  end

  def test_should_raise_error_with_bad_login
    VCR.use_cassette("AmazonReportScraper/with_bad_login/raise_error") do
      assert_raises Compactor::Amazon::AuthenticationError do
        scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      end
    end
  end

  def test_should_raise_error_with_no_email_or_password
    VCR.use_cassette("AmazonReportScraper/with_bad_login/raise_error") do
      assert_raises Compactor::Amazon::AuthenticationError do
        scraper = Compactor::Amazon::ReportScraper.new({})
      end
    end
  end

  def test_should_raise_error_with_locked_account
    VCR.use_cassette("AmazonReportScraper/with_locked_account/raise_error") do
      assert_raises Compactor::Amazon::LockedAccountError do
        scraper = Compactor::Amazon::ReportScraper.new(:email => "far@far.away", :password => "test")
      end
    end
  end
end
