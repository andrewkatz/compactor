module Compactor
  module Amazon
    class ScrapedRow
      def initialize(node, mechanize)
        @node      = node
        @mechanize = mechanize
      end

      def can_download_report?
        !report_buttons.blank?
      end

      def report_buttons
        last_cell.search(".secondarySmallButton").map do |ele|
          Mechanize::Page::Link.new(ele.parent, @mechanize, @mechanize.page)
        end
      end

      def download_report!(validate=false)
        r_type, r_data = download_report

        # fail if Amazon is saying that total is X but the calculated total is Y
        validate!(r_type, r_data) if validate

        [r_type, r_data]
      end

      def download_report
        buttons           = report_buttons
        button_index      = index_of_button(buttons)
        report_url        = buttons[button_index].node["href"]
        report_identifier = buttons[button_index].node.search(".button_label").text
        type              = ReportScraper.report_type(report_identifier)
        response_body     = @mechanize.get(report_url).body

        [type, response_body]
      end

      def reload
        table_rows.each do |row|
          row = ScrapedRow.new(row, @mechanize)
          return row if row.date_range == date_range
        end

        nil
      end

      def request_report
        button    = last_cell.search(".regenerateButton")[0]
        button_id = button['id']

        @mechanize.post("/gp/payments-account/redrive.html", {
          "groupId" => button_id
        })
      end

      # A settlement period (row) is considered ready to be parsed
      # if it's not processing, open or in progress. Also the "regenerate" 
      # button is not present. This means that all is left is 1 or more
      # buttons to get the actual reports
      def requestable_report?
        !last_cell.search(".regenerateButton").empty?
      end

      def not_settled_report?
        text = last_div.text

        # Is the report not settled yet? (in pending-like state)
        ["(Processing)", "(Open)", "In Progress"].any? do |report_state|
          text.include?(report_state)
        end
      end

      def deposit_amount
        @deposit_amount = fetch_deposit_amount if !@deposit_amount
        @deposit_amount
      end

      def date_range
        @date_range ||= @node.search("td:first-child a").text
      end

      private

      def validate!(r_type, r_data)
        return true unless r_type == :xml # only check xml for now

        parser = Compactor::Amazon::XmlParser.new(r_data)
        unless parser.valid?
          error_message = \
            "Amazon generated report has a TotalAmount discrepancy. {" +
              "type: XML, " +
              "expected total: $#{"%.2f" % parser.expected_total}, " +
              "calculated total: $#{"%.2f" % parser.calculated_total}, " +
              "difference: $#{"%.2f" % (parser.expected_total - parser.calculated_total).abs}" +
            "}"
          raise ReportTotalsMismatch.new(error_message)
        end

        true
      end

      def last_div
        last_cell.search("div")[-1]
      end

      def fetch_deposit_amount
        deposit_cell = @node.search("td")[-2]
        deposit_cell ? deposit_cell.text.gsub(/[^0-9\.]/, '').to_f : 0.0
      end

      def table_rows
        @mechanize.page.search("tr")
      end

      def last_cell
        @last_cell ||= @node.search("td")[-1]
      end

      def index_of_button(buttons)
        raise MissingReportButtons if buttons.blank? # no buttons at all!

        buttons.each_with_index do |button, index|
          # XML is preferred
          return index if button.node.search(".button_label").text == "Download XML"
        end

        # No XML, look for another type of report, use the first one, whatever
        # the type
        0
      end
    end
  end
end