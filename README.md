# sqlbook!

sqlbook is an open source alaytics tool for data nerds. It captures analytics events and provides a SQL interface and visualisation framework.

It is made up of two main parts: the Ruby on Rails application, and a script that is loaded on users' websites to capture the data.

## Using the hosted version of sqlbook

sqlbook has a free tier, and charges per event after the free tier has been exceeded. No credit card is required, and you can sign up now at [https://sqlbook.com/auth/signup](https://sqlbook.com/auth/signup)


## Self-hosting sqlbook

sqlbook is open source and can be self hosted, however it is only for personal use and cannot be resold. Please check the licence for more information.

### Requirements

- Ruby (see `/.ruby-version`)
- Node.js (>= v18)
- Postgres
- AWS

### Installation

This assumes you already have Ruby, Node.js and Postgres already installed.

```
$ git clone git@github.com:sqlbook/sql_book.git
$ bundle install
```

## Create the databases
```
$ bundle exec rails db:create
```

## Create the readonly events user
```
$ bundle exec rake readonly_events_user:create
$ RAILS_ENV=test bundle exec rake readonly_events_user:create
```

## Run the migrations
```
$ bundle exec rails db:migrate
$ RAILS_ENV=test bundle exec rails db:migrate
```

### Running the tests

```
$ bundle exec rspec
```

### Running the linter

```
$ bundle exec rubocop
```

### Start the dev server

```
$ bin/dev
```
