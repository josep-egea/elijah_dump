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
    # raise @page_doc.content
    # raise @page_doc.to_yaml
    @page_content = @page_doc.at_css('.markdown-body')
    # raise @page_content.content
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

  def process_main_content
    header = @page_chapters[@index_h1][:header]
    contents = @page_chapters[@index_h1][:contents]
    if header
      @meeting.title = header.content.strip
    else
      @meeting.title = 'Terracismo.rb'
    end
    details = []
    contents.each do |node|
      case node.name
      when 'hr'
        next  # Ignore rules
      when 'h3'
        if (link = node.at_css('a[2]'))
          @meeting.video_url = link[:href] if node.text =~ /v(í|i)deo/i
          @meeting.slides_url = link[:href] if node.text =~ /slide/i
        end
      else
        unless header.nil? && node_has_metadata?(node)
          # This condition prevents the metadata block in Terracismo.rb from showing up
          details << node.to_html
        end
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
    @found_links.concat(header.css('a').to_a) unless header.nil?
  end

  def process_metadata
    get_content_for_metadata
    metadata_node = @nodes_for_metadata.first.at_css('tbody tr')
    parse_date(metadata_node.at_css('td[1]').text)
    parse_time(metadata_node.at_css('td[2]').text)
    parse_venue(metadata_node.at_css('td[3]').text)
    @nodes_for_metadata.each do |node|
      @found_links.concat(node.css('a').to_a)
    end
  end
  
  def get_content_for_metadata
    if @nodes_for_metadata.nil? || @nodes_for_metadata.empty?
      # If present, metadata is always in the first chapter
      @page_chapters[0][:contents].each do |node|
        if node_has_metadata?(node)
          @nodes_for_metadata << node
        end
      end
    end
    raise "No contents for metadata in page!" if @nodes_for_metadata.nil? || @nodes_for_metadata.empty?
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
  
  def find_indexes
    omit_speaker = false
    @page_chapters.each_index do |idx|
      h = @page_chapters[idx][:header]
      if h
        hcontent = h.content
        @index_offered_by = idx if hcontent =~ /Ofrecido por/i || hcontent =~ /Offered by/i
        @index_attendees = idx if hcontent =~ /Apúntense/i
        @index_resources = idx if !omit_speaker && (hcontent =~ /Recursos/i || hcontent =~ /Resources/i)
        if h.name == 'h2' && @index_h1.nil? && ![@index_offered_by, @index_attendees, @index_attendees].include?(idx) 
          # In Github pages the title is the first h2!!
          return if omit_meeting?(hcontent)
          @index_h1 = idx
          omit_speaker = meeting_without_speaker?(hcontent)
        end
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