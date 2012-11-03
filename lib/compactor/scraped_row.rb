module Compactor
  module Amazon
    class ScrapedRow
      def initialize(node, mechanize)
        @node = node
        @mechanize = mechanize
      end

      def can_download_report?
        !report_buttons.empty?
      end

      def report_buttons
        last_cell.search(".secondarySmallButton").map do |ele|
          Mechanize::Page::Link.new(ele.parent, @mechanize, @mechanize.page)
        end
      end

      def download_report
        report_url        = report_buttons[0].node["href"]
        report_identifier = report_buttons[0].node.search(".button_label").text
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

      def ready?
        div = last_cell.search("div")[-1]
        text = div.text

        ignorable_periods = ["(Processing)", "(Open)", "In Progress"]
        !ignorable_periods.any? { |ignore_text| text.include?(ignore_text) &&
          div.search(".regenerateButton").blank? }
      end

      def deposit_amount
        @deposit_amount = fetch_deposit_amount if !@deposit_amount

        @deposit_amount
      end

      def date_range
        @date_range ||= @node.search("td:first-child a").text
      end

      private

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
    end
  end
end