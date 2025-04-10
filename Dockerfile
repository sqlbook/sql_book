FROM arm64v8/ruby:3.4.2-alpine

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

RUN yarn build --minify
RUN yarn build_script --define:process.env.WEBSOCKET_URL="'https://sqlbook.com/events/in'" --minify

# Yes this is a real thing in Rails
RUN SECRET_KEY_BASE_DUMMY=1 rails assets:precompile

EXPOSE 3000

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
