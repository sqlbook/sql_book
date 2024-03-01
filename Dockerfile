FROM arm64v8/ruby:3.3.0-alpine

WORKDIR /app

ENV RUBY_YJIT_ENABLE=1

RUN apk --update add build-base ruby-dev postgresql-dev tzdata gcompat nodejs npm

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true

RUN npm install -g yarn

COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
COPY package.json /app/package.json
COPY yarn.lock /app/yarn.lock

RUN bundle install

RUN yarn install

COPY . /app

RUN yarn build

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
