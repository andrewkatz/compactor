# Compactor

[![Build Status](https://secure.travis-ci.org/julio/compactor.png)](http://travis-ci.org/julio/compactor)

Scrape Amazon Seller Central

## Installation

Add this line to your application's Gemfile:

    gem 'compactor'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install compactor

## Usage

```
rake test:coverage
```

```ruby
def scrape(email, password, from, to)
  scraper = Compactor::Amazon::ReportScraper.new(:email => email, :password => password)
  marketplaces = scraper.marketplaces

  original_from = from
  original_to   = to

  marketplaces.each do |marketplace|
    scraper.select_marketplace marketplace[1]

    from = original_from
    to   = original_to

    puts "Marketplace: #{marketplace[1]}"
    while from < to
      begin
        reports_by_type = scraper.reports(from, to)
        puts "There are #{reports_by_type.size} reports between #{from.to_date} and #{to.to_date}"
      rescue Exception => e
        puts "ERROR: #{e.message} - USER: #{email}"
      end
      from += 1.week
    end
  end
end

scrape "me@there.com", "secret", DateTime.parse("1/1/2012"), DateTime.now
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Contributors

* Trae Robrock ( https://github.com/trobrock )
* Julio Santos ( https://github.com/julio )

## To-do

- Refactor
- 100% coverage