FROM ruby:3.3.5-alpine

RUN gem install brakeman -v 6.2.1

COPY lib /action/lib

CMD ["ruby", "/action/lib/index.rb"]
