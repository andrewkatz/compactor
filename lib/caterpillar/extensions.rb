module Enumerable
  def sum(identity = 0, &block)
    if block_given?
      map(&block).sum(identity)
    else
      inject(:+) || identity
    end
  end
end

module Nokogiri
  class MissingElement < ::StandardError; end

  module XML
    class Node
      def search!(selector)
        result = search(selector)
        if result.blank?
          fail MissingElement.new("No elements for [#{selector}]")
        end
        result
      end
    end
  end
end

class Mechanize::Page
  def_delegator :parser, :search!, :search!
end

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end