# Scraper for Google showtime search.
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Victor Costan
# License:: MIT

require 'net/http'
require 'set'
require 'uri'

require 'nokogiri'

# Scraper for Google's movie showtimes search.
#
# The #for method is the only method intended to be used by client code. See its
# documentation to get started.
module GoogleShowtimes
  # Searches Google (google.com/movies) for movie showtimes.
  #
  # Args:
  #   movie:: the name of the movies
  #           if nil, will retrieve all the showtimes at the given location
  #   location:: a string containing the location to search for 
  #              Google is awesome at geocoding, so throw in zipcodes,
  #              addresses, cities, or hoods
  #
  # Returns a string containing the Google-disambiguated location, and an array
  # of hashes. One hash has showtimes for a film at a cinema and looks like
  # this:
  #     { :cinema => { :name => 'AMC 13', :address => '1998 Broadway, ....' },
  #       :film => { :name => 'Dark Knight', :imdb => '0123456' },
  #       :showtimes => [ { :time => '11:30am' },
  #                       { :time => '1:00', :href => 'site selling tickets' } ]
  #     }
  def self.for(location, movie = nil)
    query = if movie
      "/movies?q=#{URI.encode(movie)}&near=#{URI.encode(location)}"
    else
      "/movies?near=#{URI.encode(location)}"
    end
  
    results = []
    google_location = nil
    while query
      response = Net::HTTP.start("google.com", 80) { |http| http.get query }
      unless response.kind_of? Net::HTTPSuccess
        return nil
      end
    
      partial_results, location, query = parse_results response.body
      google_location ||= location
      results += partial_results
    end
    return google_location, results
  end
    
  # Parses a Google showtimes results page.
  #
  # Args:
  #   nokogiri:: a Nokogiri document for the Google showtimes results page
  #
  # Returns an array of results, a string containing the Google-disambiguated
  # location, and a string containing the URL for the 'Next >' link. The first
  # two return values are structured like return of the #for method. The last
  # string may be nil if the results page contains no 'Next >' link.
  def self.parse_results(page_contents)
    nokogiri = Nokogiri::HTML page_contents    
    
    location = parse_location nokogiri
    next_url = parse_next_link nokogiri
    results = []
  
    theater, movie = nil, nil
    parse_results_fast nokogiri do |info_type, info|
      case info_type
      when :movie
        movie = info
      when :theater
        theater = info
      when :times
        results << { :film => movie, :cinema => theater, :showtimes => info }
      end
    end
    return results, location, next_url
  end
  
  # Parses a Google showtimes results page.
  #
  # This method uses a fast parsing method, assuming the well-behaved output
  # page produced by Google at the time of the gem's writing.
  #
  # Args:
  #   nokogiri:: a Nokogiri document for the Google showtimes results page
  #
  # Yields a symbol and information hash for every piece of information found.
  # The symbol is either +:theater+, +:movie+, or +:times+. The information is
  # the same as in the #for method.
  def self.parse_results_fast(nokogiri, &block)
    query = '//div[@class="movie" or @class="theater" or @class="times"]'
    nokogiri.xpath(query).each do |div|
      case div['class']
      when 'theater'
        if info = parse_theater_fast(div)
          yield :theater, info
        end
      when 'movie'
        if info = parse_movie_fast(div)
          yield :movie, info
        end
      when 'times'
        if info = parse_showing_times(div)
          yield :times, info
        end
      end
    end
  end
  
  # Parses movie theater information in a Google showtime results page.
  #
  # This method uses a fast parsing method, assuming the well-behaved output
  # page produced by Google at the time of the gem's writing.
  #
  # Args:
  #   nokogiri:: a Nokogiri node containing the movie theater data
  #
  # Returns a hash with the keys +:name+ and +:address+, or nil if parsing
  # failed.
  def self.parse_theater_fast(nokogiri)
    name_elem = nokogiri.css('.name').first
    address_elem = nokogiri.css('.address').first || nokogiri.css('.info').first
    if name_elem && address_elem
      address, phone = address_phone(address_elem.text)
      info = { :name => name_elem.text, :address => address }
      info[:phone] = phone if phone
      return info
    end
    nil
  end
    
  # Attempts to extract the phone number from an address+phone string.
  #
  # Args:
  #   text:: Google showtimes string containing an address and phone number
  #
  # Returns two strings containing the address, and the phone number. The phone
  # number will be nil if the strings could not be separated.
  #
  # Example:
  #     a, p = address_phone('234 West 42nd St., New York - (212) 398-3939')
  def self.address_phone(text)
    # The biggest suffix that consists of non-word characters.
    # HACK: One x is allowed, for extension: (800) 326-3264 x771
    ph_number = text.scan(
        /[[:digit:][:punct:][:space:]]+(?:x[[:digit:][:punct:][:space:]]+)?$/u).
        sort_by(&:length).last
    return text, nil unless ph_number
    
    address = text[0, text.length - ph_number.length]
    ph_number.gsub! /^\s*\-\s*/, ''
    
    # If it has 50% digits, it's good.
    digit_count = ph_number.scan(/\d/u).length
    return text, nil unless digit_count * 2 >= ph_number.length
    return address, ph_number
  end  
  
  # Parses movie information in a Google showtime results page.
  #
  # This method uses a fast parsing method, assuming the well-behaved output
  # page produced by Google at the time of the gem's writing.
  #
  # Args:
  #   nokogiri:: a Nokogiri node containing the movie data
  #
  # Returns a hash with the keys +:name+ and +:imdb+, or nil if parsing failed.
  def self.parse_movie_fast(nokogiri)
    name_elem = nokogiri.css('div.desc h2').first
    name_elem ||= nokogiri.css('.name').first    

    imdb = nil
    nokogiri.css('a').each do |a|
      match_data = /imdb\.com\/title\/tt(\-?\d*)\//.match a['href']
      next unless match_data
      
      imdb = match_data[1]
      return { :name => name_elem.text, :imdb => imdb }
    end
    nil
  end
  
  # Parses showing times information in a Google showtime results page.
  #
  # Args:
  #   nokogiri:: a Nokogiri node containing the showing times data
  #
  # Returns a hash with the keys +:time+ and (optionally) +:href+, or nil if
  # parsing failed.
  def self.parse_showing_times(nokogiri)
    times = []
    time_set = Set.new
    
    # Parse times with ticket buying links.
    nokogiri.css('a').each do |a|
      next unless /\d\:\d\d/ =~ a.text
      time_set << a.text
      times << { :time => a.text, :href => cleanup_redirects(a['href']) }
    end
    
    # Parse plaintext times.
    plain_times = []
    nokogiri.text.split.each do |time_text|
      time_text.gsub!(/[^\d\:amp]/, '')
      next unless /\d\:\d\d/ =~ time_text
      next if time_set.include? time_text
      time_set << time_text
      plain_times << { :time => time_text }
    end
    times = plain_times + times  # Plaintext times always precede linked times.
    
    # Parse text-form time into Time objects.
    last_suffix = ''
    (times.length - 1).downto(0) do |index|
      time = times[index][:time]
      
      if ['am', 'pm'].include? time[-2, 2]
        last_suffix = time[-2, 2]
      else
        time += last_suffix
      end
      times[index][:time] = parse_time time
    end
    times
  end
  
  # Attempts to remove Google redirects from a URL.
  def self.cleanup_redirects(url)
    match_data = /.(http\:\/\/.*?)(\&.*)?$/.match url
    return match_data ? URI.unescape(match_data[1]) : url
  end  
  
  # Parses a showtime returned by Google showtimes.
  def self.parse_time(timestr)
    time_parts = /(\d+)\:(\d\d)\W*(\w*)$/.match timestr
    time = Time.now
    if time_parts
      is_am = time_parts[3].downcase == 'am'
      is_pm = time_parts[3].downcase == 'pm'
      minute = time_parts[2].to_i
      hour = time_parts[1].to_i
      if is_pm
        hour += 12 unless hour == 12
      elsif is_am
        hour -= 12 if hour == 12
      end
      time = Time.gm(time.year, time.month, time.day, hour, minute, 0)
    end
    return time
  end  
    
  # Parses the disambiguated location from a Google showtimes results page.
  #
  # Args:
  #   nokogiri:: a Nokogiri document for the Google showtimes results page
  #
  # Returns a string containing the disambiguated location, or nil if no
  # location is found.
  def self.parse_location(nokogiri)
    nokogiri.css('h1').each do |h1|
      location_match = /^Showtimes for (.*)$/.match h1.text
      return location_match[1] if location_match
    end
    nil
  end
  
  # Extracts the URL for the "Next >" link from a Google showtimes results page.
  #
  # Args:
  #   nokogiri:: a Nokogiri document for the Google showtimes results page
  #
  # Returns the URL, or nil if no Next link exists on the results page.
  def self.parse_next_link(nokogiri)
    url = nil
    nokogiri.css('a').each do |a|
      url = a['href'] if a.text.strip == 'Next'
    end
    url
  end
end
