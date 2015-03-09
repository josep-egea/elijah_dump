# Parses a page, using one of its specialized helper classes

require './meeting'
require './topic'
require './speaker'
require './node_additions'
require './date_additions'
require './string_additions'
require 'reverse_markdown'

class JottitPageParser
  
  @page_data = nil
  @original_url = nil
  @page_doc = nil
  @page_content = nil
  @meeting = nil
  
  def parse_page(page_data, uri)
    set_page_data(page_data)
    @original_url = uri
    @meeting.original_url = @original_url
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
  end
  
  def break_page_in_chapters
    @page_chapters = @page_content.break_in_header_chapters
  end
  
  # Main processing of the page
  def parse_chapters
    find_indexes
    return if @index_h1.nil?
    process_main_header
    process_main_content
    process_metadata
    process_attendees
    process_offered_by
    remove_duplicate_topics
    generate_markdown
  end
  
  def process_main_header
    if is_multi_topic?
      details = []
      header = @page_chapters[@index_h1][:header]
      contents = @page_chapters[@index_h1][:contents]
      contents.each do |node|
        if node_has_metadata?(node)
          # These are not really details
          @nodes_for_metadata << node
        else
          details << node.to_html
        end
      end
      @meeting.title = clean_links_from_header(header)
      @meeting.details = details.join("\n")
    end
  end
  
  def process_main_content
    header = @page_chapters[@index_h1][:header]
    contents = @page_chapters[@index_h1][:contents]
    @meeting.title = clean_links_from_header(header)
    if !is_multi_topic?
      # When the meeting is not multitopic, the chapter for h1 is part or the topic too
      single_topic = @meeting.topics.first
      single_topic.topic_indexes.unshift(@index_h1) unless single_topic.topic_indexes.include?(@index_h1)
    end
    # Now we process the topics
    @meeting.topics.each_index do |topic_idx|
      process_topic(topic_idx)
    end
  end
  
  def process_topic(topic_idx)
    topic = @meeting.topics[topic_idx]
    details = []
    all_indexes = topic.topic_indexes + topic.resource_indexes + topic.additional_indexes
    all_indexes.each do |idx|
      header = @page_chapters[idx][:header]
      contents = @page_chapters[idx][:contents]
      topic.title = clean_links_from_header(header) if topic.title.nil?
      topic.found_links.concat(header.css('a').to_a) unless header.nil?
      if idx > topic.topic_indexes.first
        # For chapters beyond the first, we want the header, too
        details << header.to_html
      end
      contents.each do |node|
        if include_topic_node_in_main_content?(node)
          details << node.to_html
        end
        topic.found_links.concat(node.css('a').to_a)
      end
    end
    topic.details = details.join("\n")
    process_speakers(topic)
    process_found_links(topic)
  end
  
  def include_topic_node_in_main_content?(node)
    if @index_h1 == 0 && node_has_metadata?(node)
      # These are not really details
      @nodes_for_metadata << node
      return false
    else
      return true
    end
  end
  
  def process_speakers(topic)
    topic.speaker_indexes.each do |index_speaker|
      process_speaker(topic, index_speaker)
    end
  end
  
  def process_speaker(topic, index_speaker)
    header = @page_chapters[index_speaker][:header]
    contents = @page_chapters[index_speaker][:contents]
    speaker = header.content
    new_speaker = Speaker.new
    bio = []
    # If the handle is appended, we remove it
    new_speaker.speaker_name = speaker.gsub(/\s*(\()?\s*\@\w+\s*(\))?/, '').strip
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
    new_speaker.speaker_handle = handle_str
    new_speaker.speaker_bio = bio.join("\n")
    topic.speakers << new_speaker
  end
  
  def process_metadata
    get_content_for_metadata
    metadata_text = (@nodes_for_metadata.map {|n| n.text }).join("\n")
    parse_date(metadata_text)
    parse_time(metadata_text)
    parse_venue(metadata_text)
    # We use a dummy topic to collect the links in the metadata
    topic = Topic.new
    @nodes_for_metadata.each do |node|
      topic.found_links.concat(node.css('a').to_a)
    end
    process_found_links(topic)
    if !is_multi_topic?
      # If the single topic lacks video or slides links, we try to get them from metadata
      ftopic = @meeting.topics.first
      ftopic.video_url ||= topic.video_url
      ftopic.slides_url ||= topic.slides_url
    end
  end
  
  def process_attendees
    return if @index_attendees.nil?
    items = []
    @page_chapters[@index_attendees][:contents].each do |node|
      items.concat(node.css('li'))
    end
    @meeting.attendees = items.map {|i| i.text.strip }
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
  
  def process_found_links(topic)
    topic.found_links.each do |node|
      # Video ...
      if topic.video_url.nil? && node[:href] =~ /vimeo\.com/
        topic.video_url = node[:href]
      end
      # Slides ...
      if topic.slides_url.nil? && node.content && node.content.match(/Slides/i)
        topic.slides_url = node[:href]
      end
      # Map ...
      if @meeting.map_url.nil? && node[:href] =~ /g(oogle)?\.(com|es|co)\/maps/
        @meeting.map_url = node[:href]
      end
    end
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
  
  def clean_links_from_header(node)
    text = node.content
    return text.gsub(/\(.*?\)\s*/, '').strip
  end
  
  def remove_duplicate_topics
    @meeting.topics.uniq!
  end
  
  def generate_markdown
    if @meeting.details
      @meeting.details_md = ReverseMarkdown.convert(@meeting.details)
    end
    @meeting.topics.each do |topic|
      if topic.details
        topic.details_md = ReverseMarkdown.convert(topic.details)
      end
      topic.speakers.each do |speaker|
        if speaker.speaker_bio
          speaker.speaker_bio_md = ReverseMarkdown.convert(speaker.speaker_bio)
        end
      end
    end
  end
  
  # Tries to determine the indexes of the relevant chapters
  
  def find_indexes
    omit_speaker = false
    is_multi_speaker = is_multi_speaker?
    is_multi_topic = is_multi_topic?
    # Create the first topic
    @meeting.topics << Topic.new
    current_topic_index = 0
    @page_chapters.each_index do |idx|
      h = @page_chapters[idx][:header]
      if h
        hcontent = h.content
        if h.name == 'h1' && @index_h1.nil?
          return if omit_meeting?(hcontent)
          @index_h1 = idx
          omit_speaker = meeting_without_speaker?(hcontent)
        end
        if hcontent.match(/(Ofrecido por|Offered by)/i)
          @index_offered_by = idx
          next
        end
        if hcontent.match(/(Asistentes|Attendees|Participantes|Participants)/i)
          @index_attendees = idx
          next
        end
        if hcontent.match(/(Recursos|Resources)/i)
          @meeting.topics[current_topic_index].resource_indexes << idx
          next
        end
        if  is_multi_topic &&
            @index_h1 && 
            idx != @index_h1 &&
            idx != @index_offered_by &&
            idx != @index_attendees &&
            !@meeting.topics[current_topic_index].topic_indexes.include?(idx - 1) # Multitopic: topic/speaker alternate
          # We have found a new topic
          @meeting.topics << Topic.new
          current_topic_index += 1
          @meeting.topics[current_topic_index].topic_indexes << idx
          next
        end
        if    !omit_speaker &&
              (@meeting.topics[current_topic_index].speaker_indexes.empty? || is_multi_speaker) &&
              @index_h1 && 
              idx != @index_h1 &&
              idx != @index_offered_by &&
              idx != @index_attendees &&
              !@meeting.topics[current_topic_index].resource_indexes.include?(idx)
          @meeting.topics[current_topic_index].speaker_indexes << idx
          next
        end
        if    idx != @index_h1 &&
              idx != @index_offered_by &&
              idx != @index_attendees &&
              !@meeting.topics[current_topic_index].topic_indexes.include?(idx) &&
              !@meeting.topics[current_topic_index].resource_indexes.include?(idx) &&
              !@meeting.topics[current_topic_index].speaker_indexes.include?(idx)
          # This chapter isn't used in any special way. We will add it to the current topic
          @meeting.topics[current_topic_index].additional_indexes << idx
        end
      end
    end
    # Last. If we're multitopic and the first topic is empty, we remove it
    if is_multi_topic && @meeting.topics.first.has_no_indexes?
      @meeting.topics.shift
    end
    raise "No h1 in page! #{@page_chapters.inspect}" if @index_h1.nil?
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
  
  def is_multi_topic?
    return true if @original_url =~ /marzo_2011/
    return true if @original_url =~ /mayo_2011/
    return true if @original_url =~ /febrero_2013/
    return false
  end
  
  def is_multi_speaker?
    return true if @original_url =~ /agosto_2012/
    return true if @original_url =~ /octubre_2013/
    return false
  end
  
  # Filters out selected meetings that don't have speakers
  
  def meeting_without_speaker?(hcontent)
    return true if hcontent.match(/terracismo/i)
    return true if hcontent.match(/partido de f/i)
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