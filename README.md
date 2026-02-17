# sqlbook!

sqlbook is an open source alaytics tool for data nerds. It captures analytics events and provides a SQL interface and visualisation framework.

It is made up of two main parts: the Ruby on Rails application, and a script that is loaded on users' websites to capture the data.

## Using the hosted version of sqlbook

sqlbook has a free tier, and charges per event after the free tier has been exceeded. No credit card is required, and you can sign up now at [https://sqlbook.com/auth/signup](https://sqlbook.com/auth/signup)


## Self-hosting sqlbook

sqlbook is open source and can be self hosted, however it is only for personal use and cannot be resold. Please check the license for more information.

### Requirements

- Ruby (see `/.ruby-version`)
- Node.js (>= v18)
- Postgres
- Redis
- AWS

### Installation

This assumes you already have Ruby, Node.js and Postgres already installed.

```
$ git clone git@github.com:sqlbook/sql_book.git
$ bundle install
$ yarn install
$ yarn build
```

## Create the database users
```
$ psql -U postgres

postgres=# CREATE USER sqlbook WITH SUPERUSER;
postgres=# CREATE ROLE sqlbook_readonly WITH LOGIN PASSWORD 'password';
```

## Create the databases
```
$ bundle exec rails db:create
```

## Run the migrations
```
$ bundle exec rails db:migrate
$ RAILS_ENV=test bundle exec rails db:migrate
```

### Setup the readonly user and give permissions
```
$ db/setup.sh development
$ db/setup.sh test
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

### Quick local restart

Use this wrapper to run with sensible local Postgres defaults:

```
$ bin/dev-local
```

## Project docs

- Architecture plan: `docs/ARCHITECTURE_PLAN.md`
- Product context: `docs/PROJECT_CONTEXT.md`
- Decisions log: `docs/DECISIONS.md`
- Engineering guardrails: `docs/ENGINEERING_GUARDRAILS.md`
- GitHub working agreement: `docs/GITHUB_WORKING_AGREEMENT.md`
- Render staging plan: `docs/STAGING_RENDER_PLAN.md`
- Staging core checklist: `docs/STAGING_CORE_FUNCTIONALITY_CHECKLIST.md`
- Staging feature-surface checklist: `docs/STAGING_FEATURE_SURFACE_CHECKLIST.md`
- Env vars reference: `docs/ENV_VARS.md`
- Next-session handoff: `docs/NEXT_SESSION_RENDER_HANDOFF.md`
