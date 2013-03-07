module Compactor
  module Amazon
    class XmlParser
      attr_reader :calculated_total, :expected_total
      def initialize(xml)
        calculate(Nokogiri::XML::Document.parse(xml))
      end
      
      def valid?
        expected_total == calculated_total
      end
      
      private
      
      def calculate(doc)
        @expected_total = doc.xpath("//TotalAmount").text.to_f
        @calculated_total = 0.0
        doc.xpath("//Amount").each { |t| @calculated_total += t.text.to_f }
      end
    end
  end
end