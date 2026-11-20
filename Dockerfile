FROM ruby:4.0.10-alpine

RUN gem install brakeman -v 8.1.1

COPY lib /action/lib

CMD ["ruby", "/action/lib/index.rb"]
