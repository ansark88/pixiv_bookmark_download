#!/usr/bin/ruby
require 'rubygems'
require 'mechanize'

#http://route477.net/d/?date=20070205#p01
#http://d.hatena.ne.jp/shikaku/20091230/p3
#http://w.livedoor.jp/ruby_mechanize/d/Mechanize
#あたりを参考に

maxpage = 1 #ブックマークを辿るページ数

def login()
  username = ''
  password = ''  
  path = "http://www.pixiv.net/login.php"

  agent = Mechanize.new
  agent.user_agent_alias = 'Windows IE 7'
  agent.redirect_ok= 'true'
  agent.redirection_limit = 3

  agent.post(path,[['mode','login'],['pixiv_id',username],['pass',password],['skip',0]])
  return agent
end

#まだ1ページ分にしか対応してない
def get_bookmarkpage(agent,isprivate=nil,page=1)
  bkmstr = []
  bookmarklist = []

  if isprivate == true
    agent.get("http://www.pixiv.net/bookmark.php?rest=hide&p=#{page}")
  else
    agent.get("http://www.pixiv.net/bookmark.php?p=#{page}")
  end

  bkmhtml = agent.page.at('div.display_works')

  (bkmhtml/:a).each do |link|
    #puts "#{link.inner_html} -> #{link[:href]}"
    bookmarklist << link[:href] if /php\?illust_id/ =~ link[:href]
  end
  return bookmarklist
end

def getorguri(baseuri)
  baseuri.gsub("_m\.","\.")
end

def getid(uri)
  #puts uri
  /id=([0-9]+)/ =~ uri
  return $1
end

def extractid(linklist)
  iid = []
  linklist.each { |l| iid << getid(l) }
  return iid
end

def addlog(illustid)
  File.open("download.log","a"){ |f|
    illustid.each { |n|
      nowtime = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      text = "#{n} , #{nowtime}"
      f.write text
      f.write "\n"
    }
  }
end

def loadlog(filename)
  File.open(filename) {|f|
    logdata = f.read
    return logdata
  }
end

def existlog?(log,illustid)
  return (/#{illustid}/ =~ log) ? true : false
end

def download(ua,illustid)
  log = loadlog("download.log") if File.exist?("download.log")

  illustid.each { |iid|

    getpage = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{iid}"

    if existlog?(log,iid) == true
      puts "#{getpage} exist in log."
      next
    end

    begin
      file = ua.get(getpage)
    rescue Mechanize::ResponseCodeError , Net::HTTPNotFound => e
      puts e
      next
    else

      baseuri = ua.page.at('div.works_display a')
      imguri = ua.page.at('div.works_display a img')
      imguri =  imguri[:src]
      referer = "http://www.pixiv.net/#{baseuri[:href]}"

      #manga形式ならさらに分岐させる
      if (/mode=manga/ =~ baseuri[:href])
        i = 0
        wloop = true
        while wloop == true
          orguri = imguri.gsub("_m","_p#{i}")
          begin
            file = ua.get(orguri,nil,referer)
          rescue Mechanize::ResponseCodeError , Net::HTTPNotFound => e
            puts e
            wloop = false
            next
          else
            file.save
            puts "Download -> #{orguri}"
            addlog("#{iid}_#{i}")
            i += 1
          end
        end
      else
        orguri = getorguri(imguri)
        file = ua.get(orguri,nil,referer)
        file.save
        puts "Download -> #{orguri}"
        addlog(iid)
      end
    end
  }
end


myagent = login()

bookmarklist = []
for i in 1..maxpage
  bookmarklist = bookmarklist + get_bookmarkpage(myagent,nil,i) + get_bookmarkpage(myagent,true,i)
end
linklist = extractid(bookmarklist)
download(myagent,linklist)

