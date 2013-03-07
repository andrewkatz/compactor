require File.dirname(__FILE__) + '/test_helper'
require File.dirname(__FILE__) + '/../lib/compactor'

class ScrapedRowTest < Test::Unit::TestCase
  def test_should_be_nil_on_reload_if_no_more_table_rows_present
    Compactor::Amazon::ScrapedRow.any_instance.stubs(:table_rows).returns([])
    assert_nil Compactor::Amazon::ScrapedRow.new("node", "mechanize").reload
  end
  
  def test_should_fail_if_flagged_to_validate_and_xml_totals_do_not_match
    Compactor::Amazon::ScrapedRow.any_instance.stubs(:download_report).returns([:xml,"<xml/>"])
    Compactor::Amazon::XmlParser.any_instance.stubs(:valid?).returns(false)

    row = Compactor::Amazon::ScrapedRow.new("node", "mechanize")
    assert_raises Compactor::Amazon::ReportTotalsMismatch do
      row.download_report! true
    end
  end

  def test_should_not_fail_if_flagged_to_validate_and_xml_totals_do_not_match_and_not_xml
    Compactor::Amazon::ScrapedRow.any_instance.stubs(:download_report).returns([:tsv,"tsv"])
    Compactor::Amazon::XmlParser.any_instance.stubs(:valid?).returns(false)

    row = Compactor::Amazon::ScrapedRow.new("node", "mechanize")
    assert_nothing_raised do
      row.download_report! true
    end
  end

  def test_should_not_fail_if_flagged_to_validate_and_xml_totals_match
    Compactor::Amazon::ScrapedRow.any_instance.stubs(:download_report).returns([:xml,"<xml/>"])
    Compactor::Amazon::XmlParser.any_instance.stubs(:valid?).returns(true)

    row = Compactor::Amazon::ScrapedRow.new("node", "mechanize")
    assert_nothing_raised do
      row.download_report! true
    end
  end

  def test_should_not_fail_if_not_flagged_to_validate_and_xml_totals_do_not_match
    Compactor::Amazon::ScrapedRow.any_instance.stubs(:download_report).returns([:xml,"<xml/>"])
    Compactor::Amazon::XmlParser.any_instance.stubs(:valid?).returns(false)

    row = Compactor::Amazon::ScrapedRow.new("node", "mechanize")
    assert_nothing_raised do
      row.download_report!
    end
  end

  def test_should_not_fail_if_not_flagged_to_validate_and_xml_totals_not_match
    Compactor::Amazon::ScrapedRow.any_instance.stubs(:download_report).returns([:xml,"<xml/>"])
    Compactor::Amazon::XmlParser.any_instance.stubs(:valid?).returns(true)

    row = Compactor::Amazon::ScrapedRow.new("node", "mechanize")
    assert_nothing_raised do
      row.download_report!
    end
  end
  
  def test_should_know_if_the_expected_total_matches_the_calculated_total
    report_data = <<-XML
    <xml>
      <report>
        <TotalAmount>10</TotalAmount>
        <Amount>5</Amount>
        <Amount>5</Amount>
      </report>
    </xml>
    XML
    parser = Compactor::Amazon::XmlParser.new(report_data)
    assert parser.valid?
  end

  def test_should_know_if_the_expected_total_does_not_match_the_calculated_total
    report_data = <<-XML
    <xml>
      <report>
        <TotalAmount>10</TotalAmount>
        <Amount>5</Amount>
        <Amount>4</Amount>
      </report>
    </xml>
    XML
    parser = Compactor::Amazon::XmlParser.new(report_data)
    assert !parser.valid?
  end
end
