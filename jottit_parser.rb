require 'nokogiri'
require 'json'
require './page_fetcher'
require './jottit_page_parser'

class JottitParser 
  
  @page_fetcher = nil
  @page_parser = nil
  
  def list
    page_data = page_fetcher.get_page('http://madridrb.jottit.com/')
    doc = Nokogiri::HTML(page_data)
    pages = []
    doc.css('#pages li a').each do |link|
      pages << link[:href]
    end
    return pages
  end
  
  def process_all_pages
    puts("Processing #{parser_name} pages...")
    uris = self.list
    total_uris = uris.size
    total_ok = 0
    total_ko = 0
    meetings = []
    puts("Got #{total_uris} pages")
    uris.each do |uri|
      if omit_uri?(uri)
        puts "Ignoring page: #{uri}..."
      else
        puts "Processing page: #{uri}..."
        begin
          meeting = get_meeting(uri)
          if meeting
            meetings << meeting
            write_meeting(meeting)
            total_ok += 1
          end
        rescue
          puts "Failed for page #{uri}"
          puts $!
          total_ko += 1
        end
      end
    end
    puts("Finished processing #{total_uris} pages from #{parser_name}.")
    puts("OK:#{total_ok} - Failed:#{total_ko}")
    return meetings
  end
  
  def get_meeting(uri)
    page_data = page_fetcher.get_page(uri)
    if page_data
      meeting = page_parser.parse_page(page_data)
    end
    return meeting
  end
  
  def write_meeting(meeting)
    # puts meeting.to_yaml
  end
  
  private
  
  def parser_name
    return 'Jottit'
  end
  
  def page_fetcher
    if @page_fetcher.nil?
      @page_fetcher = PageFetcher.new
    end
    return @page_fetcher
  end

  def page_parser
    if @page_parser.nil?
      @page_parser = JottitPageParser.new
    end
    return @page_parser
  end
  
  def omit_uri?(uri)
    return false
  end
  
end
