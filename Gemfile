# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.2.2'

gem 'bootsnap', require: false
gem 'clickhouse-activerecord'
gem 'jbuilder'
gem 'pg'
gem 'puma'
gem 'rails', '~> 7.1.1'
gem 'sassc-rails'
gem 'sprockets-rails'
gem 'stimulus-rails'
gem 'turbo-rails'
gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  gem 'debug', platforms: %i[mri windows]
  gem 'rspec-rails'
  gem 'rubocop-rails'
end

group :development do
  gem 'rubocop'
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'factory_bot_rails'
  gem 'selenium-webdriver'
  gem 'simplecov', require: false
end
