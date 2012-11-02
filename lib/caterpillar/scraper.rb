module Caterpillar
  module Amazon
    class AddressParseFailure < StandardError; end
    class AuthenticationError < StandardError; end
    class LockedAccountError  < StandardError; end
    class MissingRow          < StandardError; end
    class NoMarketplacesError < StandardError; end
    class NotProAccountError  < StandardError; end
    class UnknownReportType   < StandardError; end

    ATTEMPTS_BEFORE_GIVING_UP = 15 # give up after 20 minutes
    MARKETPLACE_HOMEPAGE      = "https://sellercentral.amazon.com/gp/homepage.html"
    AMAZON_COM_MARKETPLACE_ID = 'ATVPDKIKX0DER'

    class ReportScraper
      def initialize(email, password, merchant_id)
        @merchant_id = merchant_id

        @mechanize = Mechanize.new
        @mechanize.max_file_buffer               = 4 * 1024 * 1024
        @mechanize.max_history                   = 2
        @mechanize.agent.http.verify_mode        = OpenSSL::SSL::VERIFY_NONE
        @mechanize.agent.http.reuse_ssl_sessions = false

        randomize_user_agent!
        login_to_seller_central email, password
      end

      def self.submit_form!(form)
        form.submit
      rescue Mechanize::ResponseCodeError => e
        raise ::Caterpillar::Amazon::NotProAccountError if e.message.include?("403 => Net::HTTPForbidden")
        raise # any other error just re-raise it
      end

      def self.authorized_user?
        message_box_error.empty? ||
        !message_box_error.text.include?('There was an error with your email/password combination.')
      end

      def self.merchant_identification(credentials={})
        @agent = Mechanize.new
        @agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        @agent.agent.http.reuse_ssl_sessions = false
        @agent.get 'https://sellercentral.amazon.com/gp/mws/registration/register.html'
        form = @agent.page.forms.first
        form.email    = credentials[:email]
        form.password = credentials[:password]
        submit_form! form

        raise Caterpillar::Amazon::AuthenticationError unless authorized_user?

        form = @agent.page.forms.first
        form.developerName   = credentials[:developer_name]
        form.devMWSAccountId = credentials[:dev_account_id]
        form.radiobutton_with(:value => 'devAuthorization').checked=true
        form.submit

        form = @agent.page.forms.first
        form.checkbox_with(:name => 'agreeCheckBox').checked=true
        form.checkbox_with(:name => 'understandCheckBox').checked=true
        form.submit

        @agent.page.forms.first.submit
        merchant_id    = @agent.page.parser.xpath('//table[@class="registration-key-table"]/tr[2]/td[1]').text
        marketplace_id = @agent.page.parser.xpath('//table[@class="registration-key-table"]/tr[3]/td[1]').text

        [merchant_id, marketplace_id]
      end

      def marketplaces
        marketplaces = filter_marketplaces(get_marketplaces)
        raise NoMarketplacesError if marketplaces.empty?

        marketplaces.map do |account_name, marketplace_id|
          select_marketplace(marketplace_id)
          balance = get_balance

          [ account_name, marketplace_id, balance ]
        end
      end

      def get_marketplaces
        @mechanize.get MARKETPLACE_HOMEPAGE

        marketplace_selector = @mechanize.page.search("#marketplaceSelect").first
        if marketplace_selector
          result = []
          marketplace_selector.search("option").each do |ele|
            name = ele.text
            marketplace_id = ele["value"]
            result << [ name, marketplace_id ]
          end
          return result
        end

        marketplace_name = @mechanize.page.search("#market_switch")
        if marketplace_name
          return [ [ marketplace_name.text.strip, nil ] ]
        end

        return []
      end

      def select_marketplace(marketplace_id)
        marketplace_id = CGI.escape(marketplace_id)
        @mechanize.get "https://sellercentral.amazon.com/gp/utilities/set-rainier-prefs.html?ie=UTF8&&marketplaceID=#{marketplace_id}"
      end

      def get_balance
        go_to_past_settlements('', '')
        return 0.0 if page_has_no_results?
        open_row = report_rows.detect { |row| !row.ready? }
        return 0.0 if open_row.nil?
        open_row.deposit_amount
      end

      def reports(from, to)
        from, to = parse_dates(from, to)
        go_to_past_settlements(from, to)

        get_reports
      end

      def get_orders(order_ids)
        orders_hash = {}
        order_ids.each do |order_id|
          order = {}
          @mechanize.get order_detail_url(order_id)

          # Get the buyer name
          begin
            tr = @mechanize.page.search!("//tr[@class='list-row']/td[@class='data-display-field'][text()=\"Contact Buyer:\"]").first.parent
            td = tr.search!("td[2]")
            order["BuyerName"] = td.text.strip
            td = @mechanize.page.search!("//tr[@class='list-row']/td[@class='data-display-field']/strong[text()='Shipping Address:']").first.parent
            addr_lines = td.children.map(&:text).reject { |l| l.blank? || l =~ /^Shipping Address/ }
            order["ShippingAddress"] = parse_address_lines!(addr_lines)
          rescue Exception => e
          end

          orders_hash[order_id] = order
        end
        orders_hash
      end

      private

      def message_box_error
        @agent.page.parser.css(".messageboxerror")
      end

      def slowdown_like_a_human(count)
        sleep count ** 2
      end

      def filter_marketplaces(marketplaces)
        results = []

        name, marketplace_id = marketplaces.detect do |n, m_id|
          n == 'www.amazon.com' && ( m_id.nil? || m_id == AMAZON_COM_MARKETPLACE_ID )
        end
        results << [ 'Amazon Seller Account', AMAZON_COM_MARKETPLACE_ID ] if name

        name, marketplace_id = marketplaces.detect do |n, m_id|
           n == 'Your Checkout Website' && !m_id.nil?
        end
        results << [ 'Checkout By Amazon', marketplace_id ] if name

        results
      end

      def order_detail_url(order_id)
        "https://sellercentral.amazon.com/gp/orders-v2/details?ie=UTF8&orderID=#{order_id}"
      end

      def parse_address_lines!(addr_lines)
        nbsp = "\302\240"
        addr_lines = addr_lines.map { |line| line.gsub(nbsp, " ") }
        # Assume the first line is the name of the buyer, so skip it
        addr_lines = addr_lines[1..-1].reject { |l| l =~ /^Phone:/ }

        raise AddressParseFailure if addr_lines.empty?

        citystate_line = addr_lines.pop
        city, remainder = citystate_line.split(/,\s*/)

        raise AddressParseFailure if remainder.nil?

        state, postalcode = remainder.split(/\s+/)

        {
          'street'     => addr_lines.join('\n'),
          'city'       => city,
          'state'      => state,
          'postalcode' => postalcode
        }
      end

      # Pick a random user agent that isn't mechanize
      def randomize_user_agent!
        @mechanize.user_agent = Mechanize::AGENT_ALIASES.
          keys.
          reject{ |k| k == "Mechanize" }.
          choice
      end

      def go_to_past_settlements(from, to)
        from = CGI.escape(from)
        to   = CGI.escape(to)

        @mechanize.get "https://sellercentral.amazon.com/gp/payments-account/past-settlements.html?endDate=#{to}&startDate=#{from}&pageSize=Ten"
      end

      def get_reports
        reports = {}
        page_num = 0
        begin
          get_reports_in_page.each do |report_type, report_streams|
            reports[report_type] ||= []
            reports[report_type] << report_streams
          end

          page_num += 1
        end while pages_to_parse

        reports.each { |type, streams| streams.flatten! }
      end

      def self.xml_report?(report_identifier)
        report_identifier == "Download XML"
      end

      def self.text_v1_report?(report_identifier)
        report_identifier == "Download Flat File"
      end

      def self.text_v2_report?(report_identifier)
        report_identifier == "Download Flat File V2"
      end

      # Make this into a hash instead
      def self.report_type(report_identifier)
        return :xml  if xml_report?(report_identifier)
        return :tsv  if text_v1_report?(report_identifier)
        return :tsv2 if text_v2_report?(report_identifier)

        fail Caterpillar::Amazon::UnknownReportType
      end

      def rescue_empty_results(&block)
        3.times do
          yield
          break unless page_has_no_results?
        end
      end

      def timeout_fetching_reports(reports_to_watch, reports, count)
        if count > ATTEMPTS_BEFORE_GIVING_UP
          reports_downloaded     = reports.map { |type, reports| reports.size }.sum
          reports_not_downloaded = reports_to_watch.size
          total_reports          = reports_not_downloaded + reports_downloaded

          true
        else
          false
        end
      end

      # Find the report to download from a row, and add it
      # to a collection of reports. Do this while ensuring
      # that the current page stays the current page.
      def add_to_collection(reports, row)
        @mechanize.transact do
          report_type, report = row.download_report
          reports[report_type] ||= []
          reports[report_type] << report
        end
      end

      def get_reports_to_watch(reports_to_watch, reports, count=0)
        return if reports_to_watch.empty? || timeout_fetching_reports(reports_to_watch, reports, count)

        rescue_empty_results { @mechanize.get @mechanize.page.uri }
        reports_to_watch.reject! do |row|
          row = row.reload
          if row.nil?
            true
          elsif row.can_download_report?
            add_to_collection(reports, row)
          end
        end

        slowdown_like_a_human(count)
        get_reports_to_watch(reports_to_watch, reports, count+1)
      end

      def pages_to_parse
        next_button = @mechanize.page.links_with(:text => "Next")[0]
        return false if next_button.nil?

        next_button.click
      end

      def report_rows
        tables = @mechanize.page.search!("#content-main-entities > table")
        rows = tables[1].search("tr[class]").select do |ele|
          ["list-row-even","list-row-odd"].include? ele["class"]
        end

        rows.map { |raw_row| ScrapedRow.new(raw_row, @mechanize) }
      end

      def page_has_no_results?
        @mechanize.page.search!(".data-display").text.include? "No results found"
      end

      def get_reports_in_page
        reports_to_watch = []
        reports = {}

        return reports if page_has_no_results?

        report_rows.each do |row|
          if row.can_download_report?
            add_to_collection(reports, row)
          elsif row.ready?
            @mechanize.transact do
              row.request_report
              reports_to_watch << row
            end
          end
        end

        get_reports_to_watch(reports_to_watch, reports)

        reports
      end

      def parse_dates(from, to)
        from = Date.parse(from.to_s).strftime("%m/%d/%y")
        to   = Date.parse(to.to_s).strftime("%m/%d/%y")

        [from, to]
      end

      def login_to_seller_central(email, password)
        @mechanize.get MARKETPLACE_HOMEPAGE
        form = @mechanize.page.forms.first
        form.email    = email
        form.password = password
        form.submit

        raise Caterpillar::Amazon::AuthenticationError if bad_login?
        raise Caterpillar::Amazon::LockedAccountError  if locked_account?
      end

      def bad_login?
        !@mechanize.page.parser.css(".messageboxerror").blank? ||
          @mechanize.page.parser.css('.tiny').text.include?('Sorry, you are not an authorized Seller Central user')
      end

      def locked_account?
        alert_box = @mechanize.page.search(".messageboxalert")
        alert_box && alert_box.text.include?("limited access to your seller account")
      end
    end
  end
end