# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Victor Costan
# License:: MIT

require 'helper.rb'

require 'date'
require 'time'

class TestGoogleShowtimes < Test::Unit::TestCase
  def test_for_location
    location, results = GoogleShowtimes.for('02139')
    assert_equal 'Cambridge, MA 02139', location, 'Location'
    
    assert_operator results.length, :>, 0, 'Showtime count'
    
    assert results.any? { |r| r[:cinema][:name].index 'AMC'},
           'Results include at least one AMC theater ' + results.inspect    
  end
  
  def test_for_movie
    # Find a movie that's running.
    location, results = GoogleShowtimes.for('02139')
    movie_name = results.first[:film][:name]
    
    location, results = GoogleShowtimes.for('02139', movie_name)
    assert_operator results.length, :>, 0, 'Showtime count'
    
    assert results.all? { |r| r[:film][:name].index movie_name },
           "All results are for the specified movie (#{movie_name}) " +
           results.inspect    
  end

  def mock_results_page(name)
    File.read File.join(File.dirname(__FILE__), 'fixtures', name + '.html')
  end

  def test_parse_results_cinemas_movies
    results, location, next_url =
       GoogleShowtimes.parse_results mock_results_page('cinemas_movies')

    assert_equal 'Cambridge, MA 02139', location, 'Location'
    assert_equal '/movies?near=02139&start=10', next_url, 'Next URL'
    assert_equal 61, results.length, 'Showtime count'
    
    golden1 = {
      :film => { :imdb => "1193138", :name => "Up in the Air"},
      :cinema => { :phone =>"(617) 499-1996", :name => "Kendall Square Cinema",
                  :address =>"1 Kendall Square, Cambridge, MA" },
      :showtimes => %w(1:00pm 2:00pm 4:00pm 5:00pm 7:00pm 8:00pm 9:45pm).
          map { |time| { :time => Time.parse(time + ' UTC') } }
    }
    assert_equal golden1, results.first, 'First result (no buy URLs)'
    
    golden46 = {
     :film => { :imdb => '0499549', :name => 'Avatar 3D'},
     :cinema => { :phone => '(888) 262-4386',
                  :name=>'AMC Loews Boston Common 19',
                  :address=> '175 Tremont Street, Boston, MA' },
     :showtimes => (%w(10:00 10:45 11:45 12:45 13:45 14:30 15:30 16:30 17:30) +
                    %w(18:15 19:15 20:15 21:15 22:00 23:00)).
         map { |time| { :time => Time.parse(time + ' UTC'),
                        :href => 'http://www.fandango.com/redirect.aspx?' +
                                 'tid=AAPNV&tmid=79830&date=2009-12-23+' +
                                 time + '&a=11584&source=google' } }
    }
    assert_equal golden46, results[46], 'First Boston Commons result (buy URLs)'
  end

  def test_parse_results_cinemas_movies_uk
    results, location, next_url =
       GoogleShowtimes.parse_results mock_results_page('cinemas_movies_uk')

    assert_equal 'London, UK', location, 'Location'
    assert_equal '/movies?near=London+UK&start=10', next_url, 'Next URL'
    assert_equal 54, results.length, 'Showtime count'
    
    golden1 = {
      :film => { :imdb => "0875034", :name => "Nine"},
      :cinema => { :phone =>"0871 224 4007", :name => "Odeon West End",
                   :address =>"40 Leicester Square, London, WC2H 7LP, UK" },
      :showtimes => %w(11:30 13:00 14:20 16:00 17:10).
          map { |time| { :time => Time.parse(time + ' UTC') } }
    }
    assert_equal golden1, results.first, 'First result (no buy URLs)'
  end
  
  def test_parse_results_movie_cinemas
    results, location, next_url =
       GoogleShowtimes.parse_results mock_results_page('movie_cinemas')

    assert_equal 'Cambridge, MA 02139', location, 'Location'
    assert_equal nil, next_url, 'No next URL'
    assert_equal 10, results.length, 'Showtime count'
    
    golden1 = {
      :film => { :imdb => '0499549', :name => 'Avatar 3D' },
      :cinema => { :name => 'AMC Loews Harvard Square 5',
                   :address => '10 Church Street, Cambridge, MA' },
      :showtimes => %w(11:30 15:15 19:00 22:45).
         map { |time| { :time => Time.parse(time + ' UTC'),
                        :href => 'http://www.fandango.com/redirect.aspx?' +
                                 'tid=AABBF&tmid=79830&date=2009-12-23+' +
                                 time + '&a=11584&source=google' } }
    }
    assert_equal golden1, results.first, 'First result (buy URLs)'    
  end
  
  def test_address_phone
    [
     ['234 West 42nd St., New York, NY',
      ['234 West 42nd St., New York, NY', nil]],
     ['40 Leicester Square, London, WC2H 7LP, UK - 0871 224 4007',
      ['40 Leicester Square, London, WC2H 7LP, UK', '0871 224 4007']]
    ].each do |text, golden_result|
      assert_equal golden_result, GoogleShowtimes.address_phone(text), text
    end
  end
  
  def test_cleanup_redirects
    [
      ['/url?q=http://www.fandango.com/redirect.aspx%3Ftid%3DAAPNV%26tmid%3D69454%26date%3D2009-12-23%2B10:45%26a%3D11584%26source%3Dgoogle&sa=X&oi=moviesf&ii=6',
       'http://www.fandango.com/redirect.aspx?tid=AAPNV&tmid=69454&date=2009-12-23+10:45&a=11584&source=google'],
      ['/url?q=http://www.imdb.com/title/tt0765010/',
       'http://www.imdb.com/title/tt0765010/']
    ].each do |text, golden_result|
      assert_equal golden_result, GoogleShowtimes.cleanup_redirects(text), text
    end
  end
  
  def test_mixed_showtime_links
    results, location, next_url =
       GoogleShowtimes.parse_results mock_results_page('mixed_showtime_links')

    assert_equal 'Cambridge, MA 02139', location, 'Location'
    assert_equal nil, next_url, 'No next URL'
    
    # Yes, Google can return negative IMDB IDs. Sigh.
    golden1 = {
      :film => { :imdb => '-1949659688', :name => "Valentine's Day" },
      :cinema => { :name => 'AMC Loews Boston Common 19',
                   :address => '175 Tremont Street, Boston, MA',
                   :phone => '(888) 262-4386' },
     :showtimes => %w(10:10 11:20 12:10 13:10 14:10).
         map { |time | { :time => Time.parse(time + ' UTC') } } +
                   %w(15:20 16:20 16:50 17:20 18:30 19:30 20:00 20:30 21:40 22:40 23:10 23:40).
         map { |time| { :time => Time.parse(time + ' UTC'),
                        :href => 'http://www.fandango.com/redirect.aspx?' +
                                 'tid=AAPNV&tmid=81193&date=2010-02-14+' +
                                 time + '&a=11584&source=google' } }
    }

    assert_equal golden1, results.first, 'First result (buy URLs)'    
  end
end
