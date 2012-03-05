# Changing this file

post '/helloworld.json' do
  tropo = Tropo::Generator.new do
    say "Thank you for calling the Avatar Addict Hotline"
  
    on :event => 'continue', :next => '/lookup_movie_time.json'
  
    ask(:name => 'zipcode') do
      say :value => 'Please speak, or enter your zipcode.'
      choices :value => '[5 DIGITS]'
    end
  end
  tropo.response
end

post '/lookup_movie_time.json' do  
  tropo_event = Tropo::Generator.parse request.env["rack.input"].read
  p tropo_event
  
  zipcode = tropo_event[:result][:actions][:zipcode][:value].gsub(" ", "")
  showtimes = avatar_showtimes_for(zipcode)

  tropo = Tropo::Generator.new do
     say "#{showtimes}. Thank you for calling, enjoy your movie!"
  end

  tropo.response
end

# Queries google for the latest Avatar movie times

def avatar_showtimes_for(zipcode)
  g = GoogleShowtimes.for(zipcode, 'Avatar')
  city = g[0].split(",")[0]
  theatre = g[1][0][:cinema][:name]
  
  text = "The closest theater to see Avatar, in #{city}," +
         " is at the #{theatre}.  The times for today are "
  
  g[1][0][:showtimes].each do |times|
    text += "#{times[:time].strftime("%I %M %p").gsub(/^0/, "")}, "
  end
  text
end
  

