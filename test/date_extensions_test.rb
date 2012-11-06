require File.dirname(__FILE__) + '/test_helper'

class DateExtensionsTest < Test::Unit::TestCase
  def test_parse_strings_separated_by_dashes
    assert_equal "01/01/12", Date.parse_to_us_format("2012-1-1")
  end

  def test_parse_strings_separated_by_slashes
    assert_equal "12/31/11", Date.parse_to_us_format("12/31/2011")
  end

  def test_convert_dates_to_strings
    assert_equal "01/01/12", Date.parse_to_us_format(Date.parse("2012-1-1"))
  end
end
