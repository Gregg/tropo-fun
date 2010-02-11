require 'rubygems'
require 'sinatra'
require 'tropo-webapi-ruby'


post '/helloworld.json' do
  tropo = Tropo::Generator.new do
    say 'Hello World!'
  end
  tropo.response
end
