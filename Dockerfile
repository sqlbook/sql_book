FROM arm64v8/ruby:3.3.0-alpine

WORKDIR /app

ENV RUBY_YJIT_ENABLE=1

RUN apk --update add build-base ruby-dev postgresql-dev tzdata gcompat nodejs npm

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true

COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock

RUN bundle install && \
  rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
  bundle exec bootsnap precompile --gemfile

RUN npm install -g yarn

RUN yarn install

COPY . /app

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 REDIS_URL=redis://localhost:6379/1 ./bin/rails assets:precompile

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
