require File.dirname(__FILE__) + '/test_helper'
require File.dirname(__FILE__) + '/../lib/compactor'

class ScrapedRowTest < Test::Unit::TestCase
  def test_should_be_nil_on_reload_if_no_more_table_rows_present
    Compactor::Amazon::ScrapedRow.any_instance.stubs(:table_rows).returns([])
    assert_nil Compactor::Amazon::ScrapedRow.new("node", "mechanize").reload
  end
end
