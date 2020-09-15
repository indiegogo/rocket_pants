# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = "rocket_pants"
  s.version     = "5.0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["sutto"]
  s.email       = []
  s.homepage    = "http://github.com/indiegogo/rocket_pants"
  s.summary     = "Indiegogo fork of OG Rocket Pants (From Darcy Laycock, http://github.com/sutto/rocket_pants"
  s.description = "Rocket Pants adds JSON API love to Rails and ActionController, making it simpler to build API-oriented controllers."
  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency 'actionpack', '>= 4.0', '< 6.0'
  s.add_dependency 'railties',   '>= 4.0', '< 6.0'
  s.add_dependency 'will_paginate', '~> 3.0'
  s.add_dependency 'hashie',        '>= 1.0', '< 4'
  s.add_dependency 'api_smith'
  s.add_dependency 'moneta'
  s.add_development_dependency 'rspec',       '>= 2.4', '< 4.0'
  s.add_development_dependency 'rspec-rails', '>= 2.4', '< 4.0'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'activerecord', '>= 3.0', '< 6.0'
  s.add_development_dependency 'sqlite3', "~> 1.3.5"
  s.add_development_dependency 'reversible_data', '~> 1.0'
  s.add_development_dependency 'kaminari'

  s.files        = Dir.glob("{lib}/**/*")
  s.require_path = 'lib'
end