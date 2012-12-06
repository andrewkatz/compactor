module Compactor
  module Amazon
    class ScrapedRow
      def initialize(node, mechanize)
        @node = node
        @mechanize = mechanize
      end

      def can_download_xml_report?
        has_xml_button?(report_buttons)
      end

      def report_buttons
        last_cell.search(".secondarySmallButton").map do |ele|
          Mechanize::Page::Link.new(ele.parent, @mechanize, @mechanize.page)
        end
      end

      def download_report
        buttons = report_buttons
        xml_index = index_of_xml_button(buttons)
        report_url        = buttons[xml_index].node["href"]
        report_identifier = buttons[xml_index].node.search(".button_label").text
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
      def ready?
        div = last_cell.search("div")[-1]
        # Ready if the data exists at all, and it's not requestable
        data_exists?(div) && !data_requestable?(div)
      end

      def deposit_amount
        @deposit_amount = fetch_deposit_amount if !@deposit_amount
        @deposit_amount
      end

      def date_range
        @date_range ||= @node.search("td:first-child a").text
      end

      private

      # If the period has the "regenerate" button, then it's requestable.
      def data_requestable?(div)
        !!div.search(".regenerateButton")
      end

      # If the period is one of the "pending" states from an Amazon point
      # of view, then we cannot fetch the data. The data doesn't exist yet.
      def data_exists?(div)
        ignorable_periods = ["(Processing)", "(Open)", "In Progress"]

        !ignorable_periods.any? { |ignore_text| div.text.include?(ignore_text) }
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

      private

      def index_of_xml_button(buttons)
        raise MissingReportButtons if buttons.blank? # no buttons at all!

        buttons.each_with_index do |button, index|
          return index if button.node.search(".button_label").text == "Download XML"
        end

        raise MissingXmlReport # failed to find an xml button on the collection of buttons
      end

      def has_xml_button?(buttons)
        return false if buttons.blank?

        buttons.any? { |button| button.node.search(".button_label").text == "Download XML" }
      end
    end
  end
end