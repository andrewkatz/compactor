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
scraper = Compactor::Amazon::ReportScraper.new(:email => "me@there.com", :password => "secret")
reports_by_type = scraper.reports(1.month.ago, Time.now)
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
