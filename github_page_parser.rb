# encoding: utf-8

# Parses a page, using one of its specialized helper classes

require './jottit_page_parser'

class GithubPageParser < JottitPageParser
    
  private
  
  def break_page_in_chapters
    @page_chapters = @page_content.break_in_header_chapters(:ignore_headers_beyond_level => 2)
  end
  
  def set_page_data(page_data)
    @page_data = page_data
    @page_doc = Nokogiri::HTML(@page_data)
    @page_content = @page_doc.at_css('.markdown-body')
    @meeting = Meeting.new()
    @nodes_for_metadata = []
    @index_h1 = nil
    @index_offered_by = nil
    @index_attendees = nil
  end

  def include_topic_node_in_main_content?(node)
    if @index_h1 == 0 && node_has_metadata?(node)
      # These are not really details
      @nodes_for_metadata << node
      return false
    end
    if node.name == 'hr' || node.name == 'h3'
      return false
    end
    super
  end

  def process_metadata
    get_content_for_metadata
    metadata_node = @nodes_for_metadata.first.at_css('tbody tr')
    parse_date(metadata_node.at_css('td[1]').text)
    parse_time(metadata_node.at_css('td[2]').text)
    parse_venue(metadata_node.at_css('td[3]').text)
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
    
  def parse_date(text)
    date = Date.strptime(text, '%Y-%m-%d')
    if date
      @meeting.meeting_date = date
    end
  end

  def parse_time(text)
    text.match(/(\d\d?\:\d\d?)/)
    time = $1
    if time
      @meeting.meeting_time = time
    end
  end

  def parse_venue(text)
    venue = text.strip
    if venue
      @meeting.venue = venue
    end
  end
  
  def clean_links_from_header(node)
    if node.nil?
      return "Terracismo.rb"
    else
      super
    end
  end
  
  def find_indexes
    omit_speaker = false
    # Create the first topic
    @meeting.topics << Topic.new
    current_topic_index = 0
    @page_chapters.each_index do |idx|
      h = @page_chapters[idx][:header]
      if h
        hcontent = h.content
        if hcontent =~ /Ofrecido por/i || hcontent =~ /Offered by/i
          @index_offered_by = idx
          next
        end
        if hcontent =~ /Apúntense/i
          @index_attendees = idx
          next
        end
        if !omit_speaker && hcontent =~ /(Recursos|Resources)/i
          @meeting.topics[current_topic_index].resource_indexes << idx
          next
        end
        if h.name == 'h2' && @index_h1.nil?
          # In Github pages the title is the first h2!!
          return if omit_meeting?(hcontent)
          @index_h1 = idx
          omit_speaker = meeting_without_speaker?(hcontent)
          next
        end
        if  !omit_speaker &&
            @meeting.topics[current_topic_index].speaker_indexes.empty?
          @meeting.topics[current_topic_index].speaker_indexes << idx
          next
        end
        # This chapter isn't used in any special way. We will add it to the current topic
        @meeting.topics[current_topic_index].additional_indexes << idx
      end
    end
    if @index_h1.nil?
      # We have no main chapter. Normally, this is a Terracismo.rb page
      @index_h1 = 0
    end
  end
  
  # Returns true if the text inside the node contains relevant field content
  
  def node_has_metadata?(node)
    first_cell = node.at_css('thead tr th')
    return (first_cell && first_cell.text =~ /fecha/i)
  end
  
  def meeting_without_speaker?(hcontent)
    return false
  end
  
  def omit_meeting?(hcontent)
    return false
  end
    
end