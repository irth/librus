require 'curb'
require 'nokogiri'

class Subject
  attr_accessor :name
  def to_s
    @name
  end
end

class Librus
  attr_accessor :cookie

  def configure_curl(curl, referer=nil, content_type=nil)
    curl.headers['User-Agent'] = 'Mozilla/5.0 (X11; Linux x86_64; rv:50.0) Gecko/20100101 Firefox/50.0'
    curl.headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    curl.headers['Accept-Language'] = 'en-US,en;q=0.5'
    curl.headers['Cache-Control'] = 'no-cache'
    curl.headers['Cookie'] = 'TestCookie=1;' + @cookie.to_s
    curl.headers['Upgrade-Insecure-Requests'] = '1'
    curl.headers['Referer'] = referer unless referer == nil
    curl.multipart_form_post = false
    curl.follow_location = false
  end

  def login(user, password)
    curl = Curl::Easy.new('https://synergia.librus.pl/loguj')
    configure_curl curl, 'https://synergia.librus.pl/loguj'

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
        @cookie = nil
        yield false
      end
    }

    curl.http_post(Curl::PostField.content('login', user),
                   Curl::PostField.content('passwd', password),
                   Curl::PostField.content('czy_js', 1))
  end

  def get_schedule
    if @cookie == nil
      # not logged in
      yield false, nil
      return
    end

    schedule = Array.new(7)
    schedule.each_index do |i|
      schedule[i] = Array.new
    end

    curl = Curl::Easy.new('https://synergia.librus.pl/przegladaj_plan_lekcji')
    configure_curl curl, 'https://synergia.librus.pl/uczen_index'

    curl.on_complete do |easy|
      page = Nokogiri::HTML(easy.body_str)
      page.css('table.plan-lekcji tr.line1').each_with_index do |tr, hour|
        tr.css('td')[1..-2].each_with_index do |td, weekday|
          # 160.chr is a non-breaking space
          if td.inner_html.to_s.strip.gsub(160.chr("utf-8"), '') != ''
            s = Subject.new
            s.name = td.css('b').inner_html
            schedule[weekday][hour] = s
          end
        end
      end
      yield true, schedule
    end

    curl.http_get
  end
end