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
    puts("Processing all pages...")
    uris = self.list
    total_uris = uris.size
    total_ok = 0
    total_ko = 0
    puts("Got #{total_uris} pages")
    uris.each do |uri|
      puts "Processing page: #{uri}..."
#      begin
        meeting = get_meeting(uri)
        puts("Got it!") if meeting
        write_meeting(meeting)
        puts("Wrote it!")
        total_ok += 1
#      rescue
#        puts "Failed for page #{uri}"
#        puts $!
#        total_ko += 1
#        raise $!  # While developing, we want to stop at the first error
#      end
    end
    puts("Finished processing #{total_uris} pages.")
    puts("OK:#{total_ok} - Failed:#{total_ko}")
  end
  
  def get_meeting(uri)
    page_data = page_fetcher.get_page(uri)
    if page_data
      meeting = page_parser.parse_page(page_data)
    end
    return meeting
  end
  
  def write_meeting(meeting)
    puts meeting.to_yaml
  end
  
  private
  
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
  
end
