FROM ruby:4.0.10-alpine@sha256:da0116fbea65c7c2f0c9d1c2d4e1e6932df1e9282683d9c4d7123f29323a2c67

WORKDIR /action

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local frozen true \
  && bundle config set --local without "development test" \
  && bundle install

COPY lib ./lib

CMD ["ruby", "/action/lib/index.rb"]
