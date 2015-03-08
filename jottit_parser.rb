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
    @venue_maps = {}
    @speaker_handles = {}
    @speaker_bios = {}
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
            update_master_dict(meeting)
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
    # Fill the missing data, if we can
    meetings.each do |meeting|
      fill_missing_data(meeting)
    end
    puts("Finished processing #{total_uris} pages from #{parser_name}.")
    puts("OK:#{total_ok} - Failed:#{total_ko}")
    return meetings
  end
  
  def get_meeting(uri)
    page_data = page_fetcher.get_page(uri)
    if page_data
      meeting = page_parser.parse_page(page_data, uri)
    end
    return meeting
  end
  
  def write_meeting(meeting)
    # puts meeting.to_yaml
  end
  
  # Records some repetitive data, like map urls for venues and speaker handles
  
  def update_master_dict(meeting)
    if meeting.venue && meeting.map_url && @venue_maps[meeting.venue].nil?
      @venue_maps[meeting.venue] = meeting.map
    end
    meeting.topics.each do |topic|
      topic.speakers.each do |speaker|
        if speaker.speaker_name
          if speaker.speaker_handle && @speaker_handles[speaker.speaker_name].nil?
            @speaker_handles[speaker.speaker_name] = speaker.speaker_handle
          end
          if speaker.speaker_bio && @speaker_bios[speaker.speaker_name].nil?
            @speaker_bios[speaker.speaker_name] = speaker.speaker_bio
          end
        end
      end
    end
  end
  
  # If the meeting lacks data like map urls or speaker handles, tries to get it from the dict created from other meetings
  def fill_missing_data(meeting)
    meeting.map_url ||= @venue_maps[meeting.venue] unless meeting.venue.nil?
    meeting.topics.each do |topic|
      topic.speakers.each do |speaker|
        if speaker.speaker_name
          speaker.speaker_handle ||= @speaker_handles[speaker.speaker_name]
          speaker.speaker_bio ||= @speaker_bios[speaker.speaker_name]
        end
      end
    end
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
    return true if uri =~ /jottit.com\/euruko/
    return true if uri =~ /jottit.com\/opurtunidad_de_ruby_on_rails_dublin/
    return true if uri =~ /jottit.com\/resa/
    return true if uri =~ /jottit.com\/book_crossing/
    return false
  end
  
end
