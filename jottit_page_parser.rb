# Parses a page, using one of its specialized helper classes

require './meeting'
require './node_additions'
require './date_additions'
require './string_additions'

class JottitPageParser
  
  @page_data = nil
  @page_doc = nil
  @page_content = nil
  @meeting = nil
  
  def parse_page(page_data)
    set_page_data(page_data)
    break_page_in_chapters
    parse_chapters
    return @meeting
  end
  
  private
  
  def set_page_data(page_data)
    @page_data = page_data
    @page_doc = Nokogiri::HTML(@page_data)
    @page_content = @page_doc.at_css('#content')
    # Remove the dateline div
    @page_content.at_css('#dateline').remove
    @meeting = Meeting.new()
    @nodes_for_metadata = []
    @index_h1 = nil
    @index_offered_by = nil
    @index_attendees = nil
    @index_speaker = nil
    @index_resources = nil
    @found_links = []
    @additional_indexes_for_main = []
  end
  
  def break_page_in_chapters
    @page_chapters = @page_content.break_in_header_chapters
  end
  
  # Main processing of the page
  def parse_chapters
    find_indexes
    return if @index_h1.nil?
    process_main_content
    process_metadata
    process_found_links
    process_speaker
    process_attendees
    process_offered_by
    find_missing_links
  end
  
  def process_main_content
    header = @page_chapters[@index_h1][:header]
    contents = @page_chapters[@index_h1][:contents]
    @meeting.title = header.content
    @found_links.concat(header.css('a').to_a)
    details = []
    contents.each do |node|
      if @index_h1 == 0 && node_has_metadata?(node)
        # These are not really details
        @nodes_for_metadata << node
      else
        details << node.to_html
      end
    end
    # If we have resources, we add after the content
    if @index_resources
      details << html_for_chapter_index(@index_resources)
    end
    # Last, if we have unassigned chapter, we add them too...
    @additional_indexes_for_main.each do |idx|
      details << html_for_chapter_index(idx)
    end
    @meeting.details = details.join("\n")
  end
    
  def process_metadata
    get_content_for_metadata
    metadata_text = (@nodes_for_metadata.map {|n| n.text }).join("\n")
    parse_date(metadata_text)
    parse_time(metadata_text)
    parse_venue(metadata_text)
    @nodes_for_metadata.each do |node|
      @found_links.concat(node.css('a').to_a)
    end
  end
  
  def process_speaker
    return if @index_speaker.nil?
    header = @page_chapters[@index_speaker][:header]
    contents = @page_chapters[@index_speaker][:contents]
    speaker = header.content
    bio = []
    # If the handle is appended, we remove it
    @meeting.speaker_name = speaker.gsub(/\s*(\()?\s*\@\w+\s*(\))?/, '')
    # Now we look for the handle in the header
    handle_str = nil
    # First, as a link
    handle_str = find_speaker_handle_in_node(header)
    if handle_str.nil?
      # If not, look for a literal Twitter handle
      handle_str = header.content.find_twitter_handle
    end
    if contents
      # Still no handle? Look in the bio links...
      handle_str = find_speaker_handle_in_node_list(contents) if handle_str.nil?
      # And the bio
      contents.each do |node|
        bio << node.to_html
      end
    end
    # Done
    @meeting.speaker_handle = handle_str
    @meeting.speaker_bio = bio.join("\n")
  end
  
  def process_attendees
    return if @index_attendees.nil?
    items = []
    @page_chapters[@index_attendees][:contents].each do |node|
      items.concat(node.css('li'))
    end
    @meeting.attendees = items.map {|i| i.text }
  end
  
  def process_offered_by
    return if @index_offered_by.nil?
    items = []
    @page_chapters[@index_offered_by][:contents].each do |node|
      items.concat(node.css('a'))
    end
    @meeting.offered_by = items.map {|i| i[:href] }
    @meeting.offered_by_html = html_for_nodes(@page_chapters[@index_offered_by][:contents])
  end
  
  # If no metadata was found in the main content, tries to find it in the prefix
  
  def get_content_for_metadata
    if @nodes_for_metadata.nil? || @nodes_for_metadata.empty?
      if @index_h1 > 0
        @page_chapters[0..(@index_h1 - 1)].each do |chapter|
          chapter[:contents].each do |node|
            if node_has_metadata?(node)
              @nodes_for_metadata << node
            end
          end
        end 
      else
        raise "No contents for metadata in page!"
      end
    end
  end
  
  def process_found_links
    @found_links.each do |node|
      # Video ...
      if @meeting.video_url.nil? && node[:href] =~ /vimeo\.com/
        @meeting.video_url = node[:href]
      end
      # Map ...
      if @meeting.map_url.nil? && node[:href] =~ /g(oogle)?\.(com|es|co)\/maps/
        @meeting.map_url = node[:href]
      end
    end
  end
  
  # Sometimes, videos are in strange places...
  
  def find_missing_links
    # TODO
  end
  
  def parse_date(text)
    date = Date.parse_madrid_rb_date(text)
    if date
      @meeting.meeting_date = date
    end
  end

  def parse_time(text)
    time = text.parse_madrid_rb_time
    if time
      @meeting.meeting_time = time
    end
  end

  def parse_venue(text)
    venue = text.parse_madrid_rb_venue
    if venue
      @meeting.venue = venue
    end
  end
  
  # Tries to determine the indexes of the relevant chapters
  
  def find_indexes
    omit_speaker = false
    @page_chapters.each_index do |idx|
      h = @page_chapters[idx][:header]
      if h
        hcontent = h.content
        if h.name == 'h1' && @index_h1.nil?
          return if omit_meeting?(hcontent)
          @index_h1 = idx
          omit_speaker = meeting_without_speaker?(hcontent)
        end
        @index_offered_by = idx if hcontent == 'Ofrecido por' || hcontent == 'Offered by'
        @index_attendees = idx if hcontent == 'Asistentes' || hcontent == 'Attendees'
        @index_resources = idx if !omit_speaker && (hcontent == 'Recursos' || hcontent == 'Resources')
        if    !omit_speaker &&
              @index_speaker.nil? &&
              @index_h1 && 
              idx != @index_h1 &&
              idx != @index_offered_by &&
              idx != @index_attendees &&
              idx != @index_resources
          @index_speaker = idx
        end
        if    idx != @index_h1 &&
              idx != @index_offered_by &&
              idx != @index_attendees &&
              idx != @index_resources &&
              idx != @index_speaker
          # This chapter isn't used in any special way. We will add it at the end of main
          @additional_indexes_for_main << idx
        end
      end
    end
    raise "No h1 in page!" if @index_h1.nil?
  end
  
  # Returns true if the text inside the node contains relevant field content
  
  def node_has_metadata?(node)
    raw_text = node.content.downcase
    return true if raw_text =~ /fecha\:\s/
    return true if raw_text =~ /hora\:\s/
    return true if raw_text =~ /lugar\:\s/
    return true if raw_text =~ /date\:\s/
    return true if raw_text =~ /time\:\s/
    return true if raw_text =~ /venue\:\s/
    # No relevant field found, so this is not a metadata block
    return false
  end
  
  # Filters out selected meetings that don't have speakers
  
  def meeting_without_speaker?(hcontent)
    return true if hcontent.match(/terracismo/i)
    return true if hcontent.match(/partido de f/i)
    return true if hcontent.match(/double feature/i)
    return true if hcontent.match(/solr vs sphinx/i)
    return false
  end
  
  # Returns true if a meeting should be ignored
  def omit_meeting?(hcontent)
    return true if hcontent.match(/book crossing/i)
  end
  
  # Tries to find an URL, looking first for Twitter user profiles. 
  # If it finds a profile, it transforms it to the @handleform
  # If there's no twitter link but there are other links, returns the first URL
  # In there are no links, returns nil
  
  def find_speaker_handle_in_node(node)
    handle = nil
    found_links = []
    links = node.css('a')
    links.each do |link|
      handle = link[:href]
      if handle =~ /twitter.com\/(\#\!\/)?(\w+)/
        return "@" + $2
      else
        found_links << handle
      end
    end
    # Still here? We found no twitter profiles. So return the first URL, if any 
    return found_links.first
  end
  
  # Looks in several nodes and returns the best result
  
  def find_speaker_handle_in_node_list(nodes)
    handles = []
    nodes.each do |node|
      handle = find_speaker_handle_in_node(node)
      handles << handle unless handle.nil?
    end
    handles.each do |handle|
      # Return the first Twitter handle
      return handle if handle =~ /\@\w/
    end
    # If still here, return the first handle
    return handles.first
  end
  
  # Returns the html of a nodes array
  def html_for_nodes(nodes)
    (nodes.map {|node| node.to_html}).join("\n")
  end
  
  # Returns the html for a chapter index
  def html_for_chapter_index(idx)
    return if idx.nil?
    res = []
    header = @page_chapters[idx][:header]
    contents = @page_chapters[idx][:contents]
    res << header.to_html if header
    if contents
      res.concat(contents.map {|node| node.to_html})
    end
    return res.join("\n")
  end
  
end