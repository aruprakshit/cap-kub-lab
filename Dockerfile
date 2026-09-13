FROM ruby:4.0.6

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local frozen true \
    && bundle install

COPY app.rb .

EXPOSE 4567

CMD ["bundle", "exec", "ruby", "app.rb"]
