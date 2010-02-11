require 'rubygems'
require 'sinatra'
require 'vendor/tropo-webapi-ruby/lib/tropo-webapi-ruby.rb'


post '/helloworld.json' do
  tropo = Tropo::Generator.new do
    say 'Hello World!'
  end
  tropo.response
end
