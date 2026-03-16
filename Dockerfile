FROM ruby:4.0.1-alpine

RUN gem install brakeman -v 8.0.4

COPY lib /action/lib

CMD ["ruby", "/action/lib/index.rb"]
