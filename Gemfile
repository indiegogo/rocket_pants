path "../"
source 'https://rubygems.org'

group :development, :test do
  gem 'pry'
  gem 'pry-byebug'
  # stable forked version of active_model_serializers in order to write an integration test
  gem 'active_model_serializers', git: 'git@github.com:indiegogo/active_model_serializers.git', branch: '0-8-stable'
  # currently tested against 5.0.7 & 5.1.7
  gem 'railties', '~> 5.1.0'
  gem 'actionpack', '~> 5.1.0'
  gem 'activerecord', '~> 5.1.0'
end

gemspec