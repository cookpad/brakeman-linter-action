# frozen_string_literal: true

source "https://rubygems.org"

gem "brakeman"

group :development, :test do
  gem "rubocop"
  gem "rubocop-performance", require: false
  gem "rubocop-rspec", require: false
end

group :test do
  # this is needed because Ruby 4 no longer ships ostruct by default
  gem "ostruct"
  gem "pry"
  gem "rexml", ">= 3.3.9"
  gem "rspec"
  gem "webmock"
end
