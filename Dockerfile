FROM ruby:4.0.10-alpine@sha256:da0116fbea65c7c2f0c9d1c2d4e1e6932df1e9282683d9c4d7123f29323a2c67

RUN gem install brakeman -v 8.1.1

COPY lib /action/lib

CMD ["ruby", "/action/lib/index.rb"]
