require 'rubygems'
require 'google_showtimes'

g = GoogleShowtimes.for('32828', 'Avatar')

puts g.first
p g[1][0]
