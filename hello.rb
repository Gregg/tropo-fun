require 'rubygems'
require 'sinatra'
require 'activesupport'
require 'vendor/tropo-webapi-ruby/lib/tropo-webapi-ruby.rb'

get '/helloworld.json' do
  
  tropo = Tropo::Generator.new do
    say 'Hello World!'
  end
  tropo.response
end