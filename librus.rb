require 'curb'

class Librus
  attr_accessor :cookie
  def initialize
    @cookie = nil
  end

  def set_curl_headers(curl)
    curl.headers['User-Agent'] = 'Mozilla/5.0 (X11; Linux x86_64; rv:50.0) Gecko/20100101 Firefox/50.0'
    curl.headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    curl.headers['Accept-Language'] = 'en-US,en;q=0.5'
    curl.headers['Cache-Control'] = 'no-cache'
    curl.headers['Referer'] = 'https://synergia.librus.pl/loguj'
    curl.headers['Cookie'] = 'TestCookie=1;' + @cookie.to_s
    curl.headers['Upgrade-Insecure-Requests'] = '1'
  end

  def login(user, password)
    curl = Curl::Easy.new('https://synergia.librus.pl/loguj')
    set_curl_headers curl
    curl.headers['Content-Type'] = 'application/x-www-form-urlencoded'
    curl.follow_location = false

    curl.on_header {|data|
      if data =~ /Set-Cookie: DZIENNIK/
        @cookie = data[12..-1].gsub(/;.*$/, '').strip
      end
      data.size
    }

    curl.on_complete {|easy|
      # librus redirects to /uczen_index if the login is successful. I can't just check if the cookie gets sent, because
      # it is sent even when the login fails.
      if easy.redirect_url == 'https://synergia.librus.pl/uczen_index'
        yield true
      else
        @cookie = ''
        yield false
      end
    }

    #TODO: use some lib to urlencode it properly
    curl.http_post("login=#{user}&passwd=#{password}&czy_js=1")
  end
end

l=Librus.new
l.login "irth", gets.strip do |result|
  puts "cookie:#{l.cookie.strip}, result:#{result}"
end